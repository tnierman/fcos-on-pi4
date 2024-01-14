#!/bin/sh

# generate-ignition.sh substitutes variables defined in the config.bu file then uses it to define an ignition file 'config.ign'

set -e

err() {
  >&2 echo "${@}"
}

## Grab all variables from the ignition file
vars=$(grep -oE "\\\$\\{.+\\}" config.bu)
if [[ -z "${vars}" ]];
then
  echo "Couldn't find any variables to check. Something's probably wrong here"
  exit 1
fi

## Check to ensure all expected variables are set. Error-out if not
echo "${vars}" | while read var;
do
  # Hacky as shit, but get the name contained in the '${variable}' format
  var_name="$(echo ${var} | awk -F{ '{print $2}' | awk -F} '{print $1}')"
  if [[ -z "${!var_name}" ]];
  then
    err
    err
    err "ERROR: '${var_name}' not set"
    err
    err "$(tput bold) All of the following variables must be set:$(tput sgr0)"
    err "${vars}"
    err
    err "$(tput bold) Current environment:$(tput sgr0)"
    err "$(printenv)"
    err "================================"
    err
    err "$(tput bold)Check the variables defined above to see what you still need to set!!!$(tput sgr0)"
    exit 2
  fi
done

## Substitute variables in config.bu for their values, invoke butane to generate the
## ignition with a 'strict' (no warnings allowed) policy, redirect resulting file to
## config.ign
envsubst < config.bu | butane --pretty --strict
