# -*- coding: utf-8 -*-
"""
Intérprete MÍNIMO de AutoLISP para probar funciones de cálculo fuera de
AutoCAD (sin dibujo: no hay entmake, command, ssget...).

Implementa alcance dinámico, enteros/reales como AutoLISP, listas,
defun con "/ locales", setq, if, cond, while, foreach, repeat, progn,
and, or, lambda, quote y las funciones de listas y matemáticas usuales.

Uso:
    from minilisp import Lisp
    L = Lisp(); L.cargar("archivo.lsp"); L.llamar("MI:FUNC", arg1, arg2)
"""
import math
import re


class Sym(str):
    pass


T = Sym("T")


class Func:
    def __init__(self, nombre, params, locales, cuerpo):
        self.nombre, self.params, self.locales, self.cuerpo = nombre, params, locales, cuerpo


class Lisp:
    def __init__(self):
        self.glob = {}
        self.pila = []
        self.builtins = {}
        self._registrar()

    # ------------------------------------------------------------ lector
    def leer(self, texto):
        texto = re.sub(r";\|.*?\|;", " ", texto, flags=re.S)
        toks = re.findall(r'"(?:[^"\\]|\\.)*"|;[^\n]*|[()\']|[^\s()\'";]+', texto)
        toks = [t for t in toks if not t.startswith(";")]
        pos = 0

        def uno():
            nonlocal pos
            t = toks[pos]
            pos += 1
            if t == "(":
                lst = []
                while toks[pos] != ")":
                    if toks[pos] == ".":
                        pos += 1
                        lst = ("DOT", lst, uno())
                        continue
                    lst.append(uno())
                pos += 1
                return lst
            if t == "'":
                return [Sym("QUOTE"), uno()]
            if t.startswith('"'):
                return t[1:-1].encode("latin-1", "replace").decode("unicode_escape", "replace") if "\\" in t else t[1:-1]
            try:
                return int(t)
            except ValueError:
                pass
            try:
                return float(t)
            except ValueError:
                return Sym(t.upper())

        out = []
        while pos < len(toks):
            out.append(uno())
        return out

    def cargar(self, ruta):
        texto = open(ruta, "rb").read().decode("latin-1")
        for f in self.leer(texto):
            if isinstance(f, list) and f and f[0] in ("DEFUN", "SETQ"):
                self.ev(f)

    # ------------------------------------------------------------ entorno
    def get(self, s):
        for marco in reversed(self.pila):
            if s in marco:
                return marco[s]
        if s in self.glob:
            return self.glob[s]
        return self.builtins.get(s)

    def set(self, s, v):
        for marco in reversed(self.pila):
            if s in marco:
                marco[s] = v
                return v
        self.glob[s] = v
        return v

    # ------------------------------------------------------------ evaluar
    def ev(self, x):
        if isinstance(x, Sym):
            if x == "T":
                return T
            if x == "NIL":
                return None
            return self.get(x)
        if not isinstance(x, list):
            return x
        if not x:
            return None
        h = x[0]
        if h == "QUOTE":
            return x[1]
        if h == "SETQ":
            v = None
            for i in range(1, len(x), 2):
                v = self.set(x[i], self.ev(x[i + 1]))
            return v
        if h == "DEFUN":
            params, locales, lista = [], [], x[2] or []
            dest = params
            for a in lista:
                if a == "/":
                    dest = locales
                else:
                    dest.append(a)
            f = Func(x[1], params, locales, x[3:])
            self.glob[x[1]] = f
            return x[1]
        if h == "LAMBDA":
            params = list(x[1] or [])
            loc = []
            if "/" in params:
                i = params.index("/")
                params, loc = params[:i], params[i + 1:]
            return Func("LAMBDA", params, loc, x[2:])
        if h == "IF":
            if self.ev(x[1]) is not None:
                return self.ev(x[2])
            return self.ev(x[3]) if len(x) > 3 else None
        if h == "COND":
            for cl in x[1:]:
                v = self.ev(cl[0])
                if v is not None:
                    for e in cl[1:]:
                        v = self.ev(e)
                    return v
            return None
        if h == "WHILE":
            v = None
            while self.ev(x[1]) is not None:
                for e in x[2:]:
                    v = self.ev(e)
            return v
        if h == "REPEAT":
            v = None
            for _ in range(int(self.ev(x[1]))):
                for e in x[2:]:
                    v = self.ev(e)
            return v
        if h == "FOREACH":
            var = x[1]
            lst = self.ev(x[2]) or []
            self.pila.append({var: None})
            v = None
            try:
                for e in lst:
                    self.pila[-1][var] = e
                    for b in x[3:]:
                        v = self.ev(b)
            finally:
                self.pila.pop()
            return v
        if h == "PROGN":
            v = None
            for e in x[1:]:
                v = self.ev(e)
            return v
        if h == "AND":
            for e in x[1:]:
                if self.ev(e) is None:
                    return None
            return T
        if h == "OR":
            for e in x[1:]:
                if self.ev(e) is not None:
                    return T
            return None
        f = self.ev(h) if isinstance(h, (Sym, list)) else h
        args = [self.ev(a) for a in x[1:]]
        return self.aplicar(f, args, h)

    def aplicar(self, f, args, nombre="?"):
        if isinstance(f, list) and f and f[0] == "LAMBDA":
            f = self.ev(f)
        elif isinstance(f, Sym):
            f = self.get(f)
        if isinstance(f, Func):
            marco = {p: (args[i] if i < len(args) else None) for i, p in enumerate(f.params)}
            for l in f.locales:
                marco[l] = None
            self.pila.append(marco)
            try:
                v = None
                for e in f.cuerpo:
                    v = self.ev(e)
                return v
            finally:
                self.pila.pop()
        if callable(f):
            return f(*args)
        raise NameError("función no definida: %s" % nombre)

    def llamar(self, nombre, *args):
        return self.aplicar(self.get(Sym(nombre.upper())), list(args), nombre)

    # ------------------------------------------------------------ builtins
    def _registrar(self):
        B = self.builtins
        b = lambda v: T if v else None

        def num(*a):
            return all(isinstance(v, int) and not isinstance(v, bool) for v in a)

        def div(a, *r):
            for v in r:
                a = (int(a / v) if num(a, v) else a / v)
            return a

        def lst(v):
            return v if v else []

        def cxr(path):
            def f(v):
                for c in reversed(path):
                    v = lst(v)
                    if c == "A":
                        v = v[0] if v else None
                    else:
                        v = v[1:] if len(v) > 1 else None
                return v
            return f

        for name in ("CAR", "CDR", "CADR", "CDDR", "CAAR", "CDAR", "CADDR", "CADDDR", "CADAR", "CDDDR"):
            B[Sym(name)] = cxr(name[1:-1])
        B.update({
            Sym("+"): lambda *a: sum(a) if a else 0,
            Sym("-"): lambda a, *r: (a - sum(r)) if r else -a,
            Sym("*"): lambda *a: math.prod(a),
            Sym("/"): div,
            Sym("1+"): lambda a: a + 1, Sym("1-"): lambda a: a - 1,
            Sym("="): lambda *a: b(all(a[0] == v for v in a[1:])),
            Sym("/="): lambda a, c: b(a != c),
            Sym("<"): lambda *a: b(all(a[i] < a[i + 1] for i in range(len(a) - 1))),
            Sym(">"): lambda *a: b(all(a[i] > a[i + 1] for i in range(len(a) - 1))),
            Sym("<="): lambda *a: b(all(a[i] <= a[i + 1] for i in range(len(a) - 1))),
            Sym(">="): lambda *a: b(all(a[i] >= a[i + 1] for i in range(len(a) - 1))),
            Sym("MIN"): lambda *a: min(a), Sym("MAX"): lambda *a: max(a),
            Sym("ABS"): abs, Sym("SQRT"): lambda a: math.sqrt(a),
            Sym("EXPT"): lambda a, c: a ** c, Sym("REM"): lambda a, c: math.fmod(a, c) if not num(a, c) else a % c,
            Sym("FIX"): lambda a: int(a) if a >= 0 else -int(-a), Sym("FLOAT"): float,
            Sym("NOT"): lambda a: b(a is None), Sym("NULL"): lambda a: b(a is None),
            Sym("LIST"): lambda *a: list(a) if a else None,
            Sym("CONS"): lambda a, c: [a] + lst(c) if isinstance(c, list) or c is None else ("DOT", a, c),
            Sym("APPEND"): lambda *a: (sum((lst(v) for v in a), []) or None),
            Sym("REVERSE"): lambda a: list(reversed(lst(a))) or None,
            Sym("LENGTH"): lambda a: len(lst(a)),
            Sym("NTH"): lambda i, a: lst(a)[i] if i < len(lst(a)) else None,
            Sym("LAST"): lambda a: lst(a)[-1] if a else None,
            Sym("ASSOC"): lambda k, a: next((e for e in lst(a) if isinstance(e, list) and e and e[0] == k), None),
            Sym("MEMBER"): lambda k, a: (lambda l: l[l.index(k):] if k in l else None)(lst(a)),
            Sym("SUBST"): lambda n, o, a: [n if e == o else e for e in lst(a)] or None,
            Sym("EQUAL"): lambda a, c, fz=0: b(a == c or (isinstance(a, (int, float)) and isinstance(c, (int, float)) and abs(a - c) <= fz)),
            Sym("EQ"): lambda a, c: b(a is c or a == c),
            Sym("DISTANCE"): lambda p, q: math.dist(p[:2] if len(p) < 3 or len(q) < 3 else p, q[:2] if len(p) < 3 or len(q) < 3 else q),
            Sym("STRCASE"): lambda s, *r: s.upper(),
            Sym("NUMBERP"): lambda a: b(isinstance(a, (int, float))),
            Sym("PRINC"): lambda *a: a[0] if a else None,
            Sym("ITOA"): str, Sym("RTOS"): lambda v, *a: "%.*f" % (a[1] if len(a) > 1 else 4, v),
            Sym("STRCAT"): lambda *a: "".join(a),
            Sym("VL-LOAD-COM"): lambda: None,
            Sym("MAPCAR"): lambda f, *ls: [self.aplicar(f, list(t)) for t in zip(*map(lst, ls))] or None,
        })

        def vl_sort(l, f):
            import functools
            def cmp(p, q):
                if self.aplicar(f, [p, q]) is not None:
                    return -1
                if self.aplicar(f, [q, p]) is not None:
                    return 1
                return 0
            return sorted(lst(l), key=functools.cmp_to_key(cmp)) or None

        B[Sym("VL-SORT")] = vl_sort
