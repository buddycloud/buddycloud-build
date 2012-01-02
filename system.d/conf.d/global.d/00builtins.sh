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

global doList doStatus doInit doBuild doPackage doArchive doComplete

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
    callIndirect initSource${SOURCE_TYPE^} # e.g. call initSourceGit if
        # SOURCE_TYPE='git'
    setState $RELEASE $PROJECT INITIALISED
}

doBuild() {
    logMessage NICE "building project."
    setState $RELEASE $PROJECT BUILT
}

doPackage() {
    logMessage NICE "packaging project."
    setState $RELEASE $PROJECT PACKAGED
}

doArchive() {
    logMessage NICE "archiving project."
    setState $RELEASE $PROJECT ARCHIVED
}

doComplete() {
    logMessage NICE "completing project."
    setState $RELEASE $PROJECT INITIALISED
}
