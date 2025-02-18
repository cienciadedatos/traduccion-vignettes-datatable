@echo off
pushd %~dp0
set R_PROFILE=%~dp0\Rprofile.site
R --quiet --no-save --no-restore
popd