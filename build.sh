#!/bin/bash

source activate base
basedir=$( cd "$(dirname "$0")" ; pwd -P )
conda env update --solver=libmamba -f ${basedir}/env.yml