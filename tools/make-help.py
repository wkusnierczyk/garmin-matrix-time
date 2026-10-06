#!/usr/bin/env python3
"""Print or check the help "make help" shows (#168).

The help lives in the Makefile, next to what it describes: a line starting "## "
documents the target or the ?= variable defined on the line right after it.

    ## Build the .prg for DEVICE and EDITION [DEVICE EDITION RELEASE]
    build:

    ## The product to build for, one of manifest.xml's
    DEVICE ?= epix2pro47mm

A target's help may end in the variables it takes, in square brackets. A variable's
help cannot go on its own line: make keeps the spaces before a trailing comment as
part of the value, so "EDITION ?= lite ## ..." would make EDITION "lite ".

    make-help.py MAKEFILE --variables         the documented variables' names
    make-help.py MAKEFILE NAME=value ...      the help, with each variable's value
    make-help.py MAKEFILE --check             fail on a target or variable without help

The values come from make, which passes them in, since only make can resolve them.
Pure Python, no SDK.
"""
import re
import sys
import textwrap

HELP_RE = re.compile(r'## (.*)$')
TARGET_RE = re.compile(r'([a-z][a-z0-9-]*):(?!=)')
VARIABLE_RE = re.compile(r'([A-Z][A-Z0-9_]*) *\?=')
TAKES_RE = re.compile(r'(.*?) *\[([A-Z0-9_ ]+)\]$')
NAME_WIDTH = 17
VALUE_WIDTH = 18
WIDTH = 100


def lines(path):
    """The Makefile's lines, with backslash continuations joined, each with its number."""
    joined, pending, start = [], '', None
    for number, line in enumerate(open(path, encoding='utf-8').read().splitlines(), 1):
        start = start or number
        if line.endswith('\\'):
            pending += line[:-1]
        else:
            joined.append((start, pending + line))
            pending, start = '', None
    return joined


def parse(path):
    targets, variables, phony, errors = {}, {}, [], []
    rules, settable = [], []
    text = lines(path)
    for i, (number, line) in enumerate(text):
        if line.startswith('.PHONY:'):
            phony += line.split(':', 1)[1].split()
        rule, variable = TARGET_RE.match(line), VARIABLE_RE.match(line)
        if rule:
            rules.append(rule.group(1))
        if variable:
            settable.append(variable.group(1))
        help = HELP_RE.match(line)
        if not help:
            continue
        following = text[i + 1][1] if i + 1 < len(text) else ''
        rule, variable = TARGET_RE.match(following), VARIABLE_RE.match(following)
        if rule:
            takes = TAKES_RE.match(help.group(1))
            targets[rule.group(1)] = (takes.group(1), takes.group(2).split()) if takes \
                else (help.group(1), [])
        elif variable:
            variables[variable.group(1)] = help.group(1)
        else:
            errors.append(f"line {number}: a ## line not followed by a target or a ?= variable")
    return targets, variables, phony, rules, settable, errors


def check(path):
    targets, variables, phony, rules, settable, errors = parse(path)
    for name in phony:
        if name not in targets:
            errors.append(f"{name} is in .PHONY but has no ## line" if name in rules
                          else f"{name} is in .PHONY but has no rule")
    for name in targets:
        if name not in phony:
            errors.append(f"{name} has a ## line but is not in .PHONY")
    for name in settable:
        if name not in variables:
            errors.append(f"{name} is a ?= variable but has no ## line")
    for name, (_, takes) in targets.items():
        for variable in takes:
            if variable not in variables:
                errors.append(f"{name} takes {variable}, which is not a documented variable")
    for error in errors:
        print(f"{path}: {error}")
    if errors:
        print("Document each one on the line before it: ## <what it does> [<VARIABLES it takes>]")
        sys.exit(1)
    print(f"Help: {len(targets)} targets and {len(variables)} variables, every one documented.")


def columns(lead, text, column):
    """lead, then text wrapped in a column of its own; below lead if lead is too wide."""
    body = textwrap.wrap(text, WIDTH - column, break_long_words=False) or ['']
    if len(lead) >= column - 1:
        print(lead)
    else:
        print(f"{lead:<{column}}{body.pop(0)}".rstrip())
    for more in body:
        print(' ' * column + more)


def show(path, values):
    targets, variables, *_ = parse(path)
    column = 2 + NAME_WIDTH + max(len(what) for what, _ in targets.values()) + 2
    print("Usage: make [target] [VARIABLE=value ...]; with no target, make builds.")
    print()
    print("Targets")
    for name, (what, takes) in targets.items():
        columns(f"  {name:<{NAME_WIDTH - 1}} {what}", ' '.join(takes), column)
    print()
    print("Variables, with the value each has now")
    for name, what in variables.items():
        columns(f"  {name:<{NAME_WIDTH - 1}} {values.get(name) or '(empty)'}", what,
                2 + NAME_WIDTH + VALUE_WIDTH)


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    path, args = argv[1], argv[2:]
    if args == ['--check']:
        check(path)
    elif args == ['--variables']:
        print(' '.join(parse(path)[1]))
    else:
        show(path, dict(arg.split('=', 1) for arg in args))


if __name__ == '__main__':
    main(sys.argv)
