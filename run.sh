#!/bin/bash
# Program:
#	Run nsjail in a template
# History:
# 2021/05/15	YingMuo
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# tips with this shell script
if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ] || [ "$4" == "" ] || [ "$5" == "" ] || [ "$6" == "" ] || [ "$7" == "" ] || [ "$8" == "" ] || [ "$9" == "" ]; then
    echo "./run.sh CONTAINER_PATH LANG_ID COMPILED INPUT OUTPUT ERROR TIME_LIMIT MEMORY_LIMIT FILE_LIMIT SECCOMP_STRING"
    echo "CONTAINER_PATH - location of contain"
    echo "LANG_ID        - id of language, 0 for c, 1 for c++, 2 for python"
    echo "COMPILED       - is compiled, 0 for false, 1 for true"
    echo "INPUT          - input file"
    echo "OUTPUT         - output file"
    echo "ERROR          - error file with error massage of nsjail, use for judge error like JGE, RE ..."
    echo "TIME_LIMIT     - time limit (s)"
    echo "MEMORY_LIMIT   - memory limit (MB)"
    echo "FILE_LIMIT     - file size limit (MB)"
    echo "SECCOMP_STRING - syscall list for seccomp rules"
    echo
    echo "e.g. ./run.sh $PWD/sandbox1 0 0 $PWD/testdata/01 $PWD/result/01 $PWD/log/01 10 512 512 \"read, newfstat, mmap, mprotect, munmap, newuname, arch_prctl, brk, access, exit_group, close, readlink, sysinfo, write, writev, lseek, clock_gettime, fcntl, pread64, openat, newstat\""
    exit 0
fi

# check source and executalbe
# EXEC=$(ls $1/main 2>/dev/null)
# if [ "${EXEC}" != "$1/main" ]; then
#     # choose language
#     if [ $2 == 0 ]; then
#         LANG=.c
#     elif [ $2 == 1 ]; then
#         LANG=.cpp
#     elif [ $2 == 2 ]; then
#         LANG=.py
#     fi
#     SRC=$(ls $1/main${LANG} 2>/dev/null)
#     if [ "${SRC}" != "$1/main${LANG}" ]; then
#         echo "NO SRC"
#         exit 0
#     fi

#     # compile
#     if [ $2 == 0 ]; then
#         gcc -O2 -w -fmax-errors=3 -std=c11 $1/main.c -lm -o $1/main
#     elif [ $2 == 1 ]; then 
#         g++ -O2 -w -fmax-errors=3 -std=c++17 $1/main.cpp -lm -o $1/main
#     fi
# fi

# check source existed
if [ $2 == 0 ]; then
    LANG=.c
elif [ $2 == 1 ]; then
    LANG=.cpp
elif [ $2 == 2 ]; then
    LANG=.py
fi
SRC=$(ls $1/main${LANG} 2>/dev/null)
if [ "${SRC}" != "$1/main${LANG}" ]; then
    echo "NO SRC"
    exit 0
fi

# compile
if [ $3 == 0 ]; then
    if [ $2 == 0 ]; then
        gcc -O2 -w -fmax-errors=3 -std=c11 $1/main.c -lm -o $1/main
    elif [ $2 == 1 ]; then 
        g++ -O2 -w -fmax-errors=3 -std=c++17 $1/main.cpp -lm -o $1/main
    fi
fi

if [ $2 == 0 ] || [ $2 == 1 ]; then
    EXEC=$(ls $1/main 2>/dev/null)
    if [ "${EXEC}" != "$1/main" ]; then
        echo "CE"
        exit 0
    fi
fi

# run process in nsjail
container=$1
container=${container#$PWD}
if [ $2 == 0 ] || [ $2 == 1 ]; then
    ./nsjail -Mo --user 99999 --group 99999 -v -R /bin/ -R /lib -R /lib64/ -R /usr/ -R /sbin/ -R $1/:$container/ --seccomp_string "${10}" -t $7 --rlimit_fsize $9 --rlimit_as $8 -x $container/main < $4 > $1/result 2>$6
elif [ $2 == 2 ]; then
    ./nsjail -Mo --user 99999 --group 99999 -v -R /bin/ -R /lib -R /lib64/ -R /usr/ -R /sbin/ -R $1/:$container/ --seccomp_string "${10}" -t $7 --rlimit_fsize $9 --rlimit_as $8 -x /bin/python3 python3 $container/main.py < $4 > $1/result 2>$6
fi

# SECCOMP ERROR
SEC=$(grep "Couldn't prepare sandboxing policy" $6)
SEC=${SEC:+Y}
if [ "${SEC}" == "Y" ]; then
    JUDGE=${JUDGE:-JGE}
fi

# NO EXECUTABLE FILE ERROR
NO_FILE=$(grep "Returning with 159" $6)
NO_FILE=${NO_FILE:+Y}
if [ "${NO_FILE}" == "Y" ]; then
    JUDGE=${JUDGE:-JGE}
fi

# NSJAIL FAIL
F=$(grep "\[F\]" $6)
E=$(grep "\[E\]" $6)
FE=$F$E
FE=${FE:+Y}
if [ "${FE}" == "Y" ]; then
    JUDGE=${JUDGE:-JGE}
fi

# T/M/OLE
JUDGE=${JUDGE:-$(grep "TLE" $6)}
JUDGE=${JUDGE:-$(grep "OLE" $6)}
JUDGE=${JUDGE:-$(grep "MLE" $6)}

# SUCCESS
SUCCESS=$(grep "Returning with 0" $6)
SUCCESS=${SUCCESS:+Y}
if [ "${SUCCESS}" == "Y" ]; then
    JUDGE=${JUDGE:-SUCCESS}
fi

# other
JUDGE=${JUDGE:-RE}

if [ ${JUDGE} == "SUCCESS" ]; then
    mv $1/result $5
else 
    touch $5
fi

# return
echo $JUDGE