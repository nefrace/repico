package tinyfiledialogs

foreign import tfd "../../tfd.a"

@(link_prefix="tinyfd_")
foreign tfd {
	beep :: proc() ---

	messageBox :: proc (
		title, message, dialogType, iconType: cstring,
		defaultButton: i32
	) -> i32 --- 

	@(link_name="tinyfd_openFileDialog")
	openFileDialog_sys :: proc(
		title, defaultPath : cstring,
		numOfPatterns: i32,
		filterPatterns: [^]cstring,
		singleFilterDescription: cstring,
		allowMultipleFiles: i32
	) -> cstring ---

	@(link_name="tinyfd_saveFileDialog")
	saveFileDialog_sys :: proc(
		title, defaultPath : cstring,
		numOfPatterns: i32,
		filterPatterns: [^]cstring,
		singleFilterDescription: cstring,
	) -> cstring ---
}

openFileDialog :: proc(
	title, defaultPath : cstring,
	filterPatterns: []cstring,
	singleFilterDescription: cstring,
	allowMultipleFiles: bool,
) -> cstring {
	return openFileDialog_sys(
		title, defaultPath,
		i32(len(filterPatterns)),
		raw_data(filterPatterns),
		singleFilterDescription,
		i32(allowMultipleFiles),
	)
}

saveFileDialog :: proc(
	title, defaultPath : cstring,
	filterPatterns: []cstring,
	singleFilterDescription: cstring,
) -> cstring {
	return saveFileDialog_sys(
		title, defaultPath,
		i32(len(filterPatterns)),
		raw_data(filterPatterns),
		singleFilterDescription,
	)
}
