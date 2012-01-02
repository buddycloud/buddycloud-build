global doBuild

doBuild() {
    if ! [ -z "$THROW_BUILD_ERR" ] ; then
        buildError "Quite deliberate build error."
        return 1
    fi
    logMessage NICE "Building project."
    setState $RELEASE $PROJECT BUILT
    return 0
}
