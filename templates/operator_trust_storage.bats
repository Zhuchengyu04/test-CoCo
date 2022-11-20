@test "Test uninstall operator" {
	skip
	helm delete open-local
	rm -r $GOPATH/open-local
	reset_runtime
}
