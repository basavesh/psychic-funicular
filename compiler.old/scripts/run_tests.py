#! /usr/bin/python

from os import system
import os.path
import sys

verbose = True
debug = False
jasminc="./jasminc.native"
all_failed = []

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def extract_enclosed(fname,marker):
    with open(fname) as f:
        lines = f.read().splitlines()
        inside = False
        start = "START:%s"%marker
        end = "END:%s"%marker
        enclosed=[]
        for l in lines:
            if not inside:
                if l == start:
                    inside = True
            else:
                if l == end:
                    return enclosed
                enclosed.append(l)
        raise "no terminator found"

def print_err(s):
    print(bcolors.FAIL + s + bcolors.ENDC)

def test(fname,get_error,cp):

    if verbose:
        print("\n%s:"%(fname)),

    fn_run_err = fname + ".run.err"
    fn_exp_err = fname + ".exp.err"
    fn_run_out = fname + ".run.out"
    fn_exp_out = fname + ".exp.out"

    # compose shell command
    arg = extract_enclosed(fname,"CMD")
    arg_set = ";\n".join(arg)
    cmd = 'sh -c \'%s;\n%s -t "$ARG" %s 2>%s.run.err >%s.run.out\''%(
             arg_set,jasminc,fname,fname,fname)

    # run and check error code
    if debug:
        print("%s"%cmd)
    err = system(cmd)
    if (err != 0) != get_error:
        print_err("error, expected %s"%("error" if get_error else "success"))
        system("cat %s; cat %s"%(fn_run_out,fn_run_err))
        return

    # remove times
    sed1 = '-E "s,[0-9]+\.[0-9]+ms,REMOVED_TIME,"'
    sed2 = '-E "s,[0-9]+\.[0-9]+ secs,REMOVED_TIME,"'
    system("sed %s  %s.run.err | sed %s | grep -v 'Python ' | grep -v 'GCC ' >%s.run.err.tmp"%(
             sed1,fname,sed2,fname))
    system("mv %s.run.err.tmp %s.run.err"%(fname,fname))
    system("sed %s %s.run.out | sed %s >%s.run.out.tmp"%(sed1,fname,sed2,fname))
    system("mv %s.run.out.tmp %s.run.out"%(fname,fname))

    # compare with expected output
    if not os.path.isfile(fn_exp_err) or not os.path.isfile(fn_exp_out):
        if cp:
            print("\n  initial version created")
            system("cp %s %s"%(fn_run_err,fn_exp_err))
            system("cp %s %s"%(fn_run_out,fn_exp_out))
        else:
            print("\n  create initial version by running")
            print("    cp %s %s"%(fn_run_err,fn_exp_err))
            print("    cp %s %s"%(fn_run_out,fn_exp_out))
            
    exp_err = open(fn_exp_err).read()
    run_err = open(fn_run_err).read()
    if exp_err!=run_err:
        print_err("error, wrong output on stderr")
        system("diff -u %s %s"%(fn_exp_err, fn_run_err))
        if cp:
            system("cp %s %s"%(fn_run_err,fn_exp_err))
        else:
            print("  run\n      cp %s %s\n  to use new definition"%(fn_run_err,fn_exp_err))
        return
    exp_out = open(fn_exp_out).read()
    run_out = open(fn_run_out).read()
    if exp_out!=run_out:
        print_err("error, wrong output on stdout")
        system("diff -u %s %s"%(fn_exp_out, fn_run_out))
        if cp:
            system("cp %s %s"%(fn_run_out,fn_exp_out))
        else:
            print("  run\n      cp %s %s\n  to use new definition"%(fn_run_out,fn_exp_out))
        return
    print(bcolors.OKGREEN + "ok" + bcolors.ENDC),

def test_fail(fname,cp=False):
    return test(fname,True,cp)

def test_ok(fname,cp=False):
    return test(fname,False,cp)

def run(fname):
    arg = extract_enclosed(fname,"CMD")
    arg_set = ";\n".join(arg)
    cmd = 'time sh -c \'%s;\n%s -t "$ARG" %s\''%(arg_set,jasminc,fname)
    system(cmd)

def print_sep():
    print("\n\n%s"%("#"*70))

######################################################################

def single_test(f):
    print("running test for %s"%(f))
    run(f)
    exit(0)

######################################################################

def all_tests():
    print_sep()

    fail_exclude = [2,22]
    for fn in [ "%02i"%i for i in range(1,24) if not i in fail_exclude ]:
        test_fail("tests/compiler/must_fail/t_%s.rs"%fn)

    print_sep()
        
    for fn in [ "%02i"%i for i in range(1,3)]:
        test_ok("tests/compiler/ok/t_%s.rs"%fn)

    # print_sep()

    #for fn in [ "%02i"%i for i in range(1,7)]:
    #    test_ok("tests/interp/ok/t_%s.mil"%fn)

    print_sep()

    for fn in [ "%02i"%i for i in range(1,4)]:
        test_ok("tests/conv/ok/t_%s.rs"%fn)

    print_sep()


if __name__ == "__main__":
  if len(sys.argv) > 1:
    single_test(sys.argv[1])
  else:
    all_tests()