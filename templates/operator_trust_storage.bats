@test "Test uninstall operator" {
	helm delete open-local
	rm -r $GOPATH/open-local
	reset_runtime
}
