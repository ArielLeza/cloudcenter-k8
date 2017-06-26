#!/bin/bash

INPUT="1,2,3"

function myfunc()
{
    local  __resultvar=$1
    local  myresult=$INPUT
    eval $__resultvar="'$myresult'"
}

myfunc OUTPUT
echo $OUTPUT
