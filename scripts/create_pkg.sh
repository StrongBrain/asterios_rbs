#!/bin/bash

echo "Executing create_pkg.sh..."

cd $path_cwd
dir_name=lambdas/asterios_rbs/

# Create and activate virtual environment...
virtualenv -p $runtime env_$function_name
source $dir_name/.venv/bin/activate

echo "Installing dependencies..."
echo "From: requirement.txt file exists..."
poetry install
# Deactivate virtual environment...
deactivate

# Create deployment package...
echo "Creating deployment package..."
cd $dir_name/lib/$runtime/site-packages/
cp -r . $path_cwd/$dir_name
cp -r $path_cwd/lambdas/asterios_rbs/ $path_cwd/$dir_name

echo "Finished script execution!"