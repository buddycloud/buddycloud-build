#!/bin/bash
#
# bc-build - script to build one or more releases of the components of buddycloud.
#
# exit codes:
#   0 - OK
#   1 - Syntax error
#   2 - Parameter error (e.g. project not found).
#   3 - unexpected internal error (e.g. can't make the project directory).

# TODO:
# - get the right messages sent to log and console. (e.g. when you do 'list').

## Define functions

# need to set some global vars before this will work.
LOG_FILE=""

setState() {
# set state of a project in a release.
# Parameters are <release> <project> <state>
    local release=$1 project=$2 state=$3
    projDir=$RELEASES_ROOT/$release/projects.d/$project
    # create project dir if necessary
    if ! [ -d $projDir ] ; then
        mkdir -p $projDir || error 3 "setState(): Error making directory - $projDir"
    fi
    echo $state > $projDir/state || error 3 "setState(): Can't write to state file - $projDir/state"
}

getState() {
# get current state of a project in a release
# parameters are <release> <project>
# if state file doesn't exist, it is created.
# returns state in $STATE
    local release=$1 project=$2
    projDir=$RELEASES_ROOT/$release/projects.d/$project
    if [ -r $projDir/state ] ; then
        STATE=`cat $projDir/state`
    else
        setState $release $project NULL
        STATE='NULL'
    fi
}

callIndirect() {
# calls a function indirectly - i.e. by giving the function name as a string.
# if the first param is --mustExist, then the function not existing is a fatal
# error.
    if [ "$1" == "--mustExist" ] ; then
        mustExist=1
        shift
    else
        mustExist=0
    fi
    if [ -n "$1" ] ; then
        funcName=$1
        shift
    else
        error 3 "Internal error - no function name given to callIndirect()"
    fi
    # Call the function.
    if declare -F $funcName > /dev/null ; then
        # a function was found to do the action.
        $funcName "$@"
        retVal=$?
    else
        [ $mustExist -eq 1 ] && \
            error 2 "no function was found to implement the call to '$funcName'."
    fi
    return $retVal
}


logMessage() {
# Write a message to the console and log file. --noConsole or --noLog can be
# used to stop messages going to the console or log file separately.
# parameters are the log level and the message.
    noLog=0 noConsole=0
    while [ "${1:0:2}" == "--" ] ; do
	case ${1:2} in
	    (noLog)
		log=0
		;;
	    (noConsole)
		console=0
		;;
	esac
    done
    msgLevel=$1
    shift
    if [[ " $LOG_LEVEL ${logLevels#*$LOG_LEVEL } " =~ " $msgLevel " ]] ; then
	if [ $noConsole -eq 0 ] ; then
	    echo -n "$indent"
    	    [ "$msgLevel" == "FATAL" ] && echo -n "Fatal error: "
	    echo $*
	fi
	[ $noLog -eq 0 ] && echo `date` $msgLevel "$indent$*" >> $LOG_FILE
    fi
}

error() {
# Throw a fatal error (i.e. one that stops the whole program).
# params are exit code and error message (which gets logged).
    code=$1
    shift
    logMessage FATAL $*
    exit $code
}

buildError() {
# Throw a build error (i.e. one that just stops one project on a release).
# param is the error message.
    logMessage ERROR $*
    setState $RELEASE $PROJECT ERROR
}

global() {
# record function or variable name(s) in the list of global names, so
# they can all be deleted later.
    while [ -n "$1" ] ; do
	    if ! [[ " ${GLOBALS[*]} " =~ " $1 " ]] ; then
	        # not already in there.
	        GLOBALS[${#GLOBALS[*]}]=$1 # push the name to GLOBALS.
	    fi
    shift
    done
}

delGlobals() {
# delete all global names defined using global.
    for glob in ${GLOBALS[*]}; do
        unset $glob
    done
    GLOBALS=()
}

## Find the bc-build system root directory.

this=$0
if [[ `ls -F $0` =~ @$ ]]; then
    this=`ls -l $0`
    this=/${this##* /}
fi
SYSTEM_ROOT=${this%%/bc-build.sh}

## Global variable default values

LOG_LEVEL=NICE # logging level
LOG_FILE=$SYSTEM_ROOT/log.d/main.log # file to log to.
GLOBALS=() # stores a list of global names, which can be deleted later.

## Local variables

# define an array of valid actions with number of parameters and usual end state.
unset actions; declare -A actions
actions=([list]="(0 -)"
         [status]="(2 -)"
         [init]="(2 INITIALISED)"
         [reset]="(2 -)"
         [source]="(2 HAVE_SOURCE)"
         [build]="(2 BUILT)"
         [package]="(2 PACKAGED)"
         [archive]="(2 ARCHIVED)"
         [complete]="(2 INIT)" )
# sequence of build actions.
buildActions=(init source build package archive complete)
# prerequisites of build actions.
unset actionPrereqs; declare -A actionPrereqs
actionPrereqs=([NULL]="init"
               [INITIALISED]="source"
               [HAVE_SOURCE]="build"
               [BUILT]="package"
               [PACKAGED]="archive"
               [ARCHIVED]="complete" )
         
logLevels="DEBUG INFO NICE WARNING ERROR FATAL" # in order of severity.

indent="" # indent level for log / console messages
    

## Startup

# set shell options
#shopt -s
logMessage NICE "Called with parameters: $*"
indent="  "
logMessage DEBUG "SYSTEM_ROOT is $SYSTEM_ROOT"

## Include the main config file.

. $SYSTEM_ROOT/conf.d/config.sh

## Parse the parameters.

parmvars=(action release project)
parms=0
while [ -n "$1" ] && [ $parms -lt 3 ]; do 
    parm=${1,,} # all parameters in lower case internally
    declare ${parmvars[$parms]}=$parm
    parms=$(( $parms + 1 ))
    shift
done
#echo action=$action release=$release project=$project

# set blank parameters to '-'

[ -z "$RELEASE" ] && RELEASE="-"
[ -z "$PROJECT" ] && PROJECT="-"

## Check the parameters.

if [ -z "$action" ] || [ "$action" == "help" ]; then
    cat <<- END
	bc-build <action> [<release>] [<project>] [--<param>[=<value>]]
	Build / package a component of the buddycloud system for a given release.
	Actions are: 
	help,list,init,reset,status,source,build,package,archive,complete
END
exit 1
fi

# is the action valid?
if ! [[ " ${!actions[*]} " =~ " ${action} " ]] ; then
    # $action is not in the list of actions.
    error 1 "$action is not a valid action"
fi

# fill in blank parameters with '-' or 'all'
eval acparms=${actions[$action]}
parms=(release project)
for (( p=0; p<2; p++ )) ; do
    eval curval=\$${parms[$p]} # current value of $release or $project
    if [ $p -ge ${acparms[0]} ] ; then
        # this parameter isn't needed.
        newval="-"
    else
        if [ -z "$curval" ] ; then
            # set parameter to 'all' if none provided.
            newval="all"
        else
            newval=$curval
        fi
    fi
    parm=${parms[$p]}
    eval $parm=$newval
done

## Do the action.

if [ "$release" == "all" ]; then 
    releases=${!RELEASES[*]} # run action for all releases.
else
    releases=$release
fi

releaseFound=0 projectFound=0
for curRelease in $releases; do
    # skip if not found.
    ! [[ " - ${!RELEASES[*]} " =~ " $curRelease " ]] && continue
    releaseFound=1
    if [ "$release" != "-" ] ; then
        eval relProjects=${RELEASES[$curRelease]}
	    if [ "$project" == "all" ]; then
	        projects=${relProjects[*]}
	    else
	        if [[ " ${relProjects[*]} " =~ " $project " ]] ; then
		        projects=$project
	        else
		        continue # project not in this release
	        fi
	    fi
    else
	    projects="-"
        relProjects="()"
    fi
    for curProject in $projects; do
        # skip if not found
        ! [[ " - ${relProjects[*]} " =~ " $curProject " ]] && continue
        projectFound=1

        # check the action prerequisites for this project.
        if [[ " ${buildActions[*]} " =~ " $action " ]] ; then
            isBuildAction=1
            getState $curRelease $curProject # returns state in $STATE.
                # (a side-effect is to create the project build directory.)
            if [ "$STATE" == "ERROR" ] ; then
                logMessage WARNING "Skipping '$curProject' in '$curRelease' - state is 'ERROR', manual fix needed."
                continue # skip this project
            fi
            nextAction=${actionPrereqs[$STATE]} # next action needed for project.
            # has the requested action been run successfully already?
            bastr="${buildActions[*]}"
            prevActions="${bastr%%$nextAction*}"
            if [[ " $prevActions " =~ " $action " ]] ; then
                # it has.
                logMessage NICE "Skipping '$curProject' in '$curRelease' - action '$action' run already."
                continue # skip this project.
            fi
        else
            nextAction=$action # not a build Action
            isBuildAction=0
        fi

        [ $isBuildAction -eq 1 ] && logMessage NICE "Working on '$curProject' in '$curRelease'"
        indent="    "
        
        # now work through the sequence of actions to bring the project to
        # the right state.
        stopState=${acparms[1]} # state we want to end with.
        while [ "$STATE" != "$stopState" ]; do
            # do everything for this action.
            ACTION=$nextAction RELEASE=$curRelease PROJECT=$curProject
            PROJECT_DIR=$RELEASES_ROOT/$RELEASE/projects.d/$PROJECT
                # The variables above are always available to the action
                # scripts.
            if [ $isBuildAction -eq 1 ] ; then
                logMessage NICE "Doing action '$ACTION'"
                cd $PROJECT_DIR # build actions can expect to be in this dir.
            fi
            
            # Read global config files.
            indent="      "
            delGlobals # remove existing global names (in case project/release='all')
            logMessage DEBUG "Reading global config files"
            globalDir=$SYSTEM_ROOT/conf.d/global.d
            [ -d $globalDir ] || error 1 can\'t find global config directory
            while read f ; do
                if [[ $f =~ .sh$ ]]; then
                    logMessage DEBUG "  $f"
                    . $SYSTEM_ROOT/conf.d/global.d/$f
                fi
            done < <(ls -1 $SYSTEM_ROOT/conf.d/global.d/)
            
            # Read action related config files.
            logMessage DEBUG "Reading action related config files."
            for dir in action release project ; do
                eval val=\$${dir^^} # convert 'dir' into value of '$ACTION' etc.
                [ "$val" == "-" ] && continue
                file=$SYSTEM_ROOT/conf.d/$dir.d/$val.sh
                if [ -f $file ] ; then
                    logMessage DEBUG "  $file"
                    . $file
                fi
            done

            # call the 'do$Action' function.
            oldState=$STATE
            callIndirect --mustExist do${ACTION^}
            retVal=$?
            if [ $retVal -ne 0 ] ; then
                # there's been a build error.
                # (the do function logs it and sets the project state.)
                break
            fi
            
            # prepare for running next action.
            if [ $isBuildAction -eq 0 ] ; then
                break
            fi
            getState $curRelease $curProject
            if [ "$STATE" == "$oldState" ] || [ "$STATE" == "ERROR" ] ||\
                [ "$ACTION" == "complete" ] ; then
                # nothing more can be done with this project.
                break
            fi
            nextAction=${actionPrereqs[$STATE]}
            indent="    "
        done # go on to next action in build sequence
        indent="  "
    done
done

if [ $acparms -ge 1 ] && [ $releaseFound -eq 0 ] ; then
    error 2 "Release '$release' not found."
fi
if [ $acparms -ge 2 ] && [ $projectFound -eq 0 ] ; then
     error 2 "Project '$project' not found."
fi
