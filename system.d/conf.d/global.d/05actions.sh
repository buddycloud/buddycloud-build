#
# Config file that contains definitions of the built in actions
# 
# these functions (and any overrides in other files) can expect to have 
# the following environment to work in.
# RELEASE - release being worked on.
# PROJECT - project being worked on.
# PROJECT_DIR - directory of project being worked on under RELEASES_ROOT
# For build actions, the current directory is set to PROJECT_DIR
# (build actions are all actions except list, status and reset).

global doList doStatus doInit doSource doBuild doPackage doArchive doComplete

doList() {
    printf "${indent}%-10s | Projects\n" Release
    echo "${indent}-------------------------------------"
    for release in ${!RELEASES[*]}; do
        printf "${indent}%-10s | " $release
        eval projects=${RELEASES[$release]}
        for project in ${projects[*]}; do
	    printf "%s " $project
	done
	printf "\n"
    done
}

doStatus() {
    getState $RELEASE $PROJECT
    echo "${indent}'$PROJECT' in '$RELEASE' is in state: $STATE"
}

doInit() {
    logMessage NICE "initialising project."
    mkdir build.d tmp.d # make build directories.
    # initialise source-y things.
    if [ -n "$SOURCE_TYPE" ] ; then
        callIndirect initSource${SOURCE_TYPE^} 
            # e.g. call initSourceGit if SOURCE_TYPE='git'
        if [ $? -eq 0 ] ; then
            setState $RELEASE $PROJECT INITIALISED
        else
            buildError "Error initialising project."
            return 1
        fi
    fi
}

doSource() {
    logMessage NICE "getting source. (dummy action)."
    setState $RELEASE $PROJECT HAVE_SOURCE
}

doBuild() {
    logMessage NICE "building project. (dummy action)."
    setState $RELEASE $PROJECT BUILT
}

doPackage() {
    logMessage NICE "packaging project. (dummy action)."
    setState $RELEASE $PROJECT PACKAGED
}

doArchive() {
    logMessage NICE "archiving project. (dummy action)."
    setState $RELEASE $PROJECT ARCHIVED
}

doComplete() {
    logMessage NICE "completing project. (dummy action)."
    setState $RELEASE $PROJECT INITIALISED
}
