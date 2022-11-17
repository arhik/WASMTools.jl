function render(filename)
	html_ = """
		<!DOCTYPE html>
		<script type="module">
		  async function init() {
		    const { instance } = await WebAssembly.instantiateStreaming(
		      fetch("$(filename).wasm"),
				{
					"env" : {
						"memset" : (...args) => { console.error("Not Implemented")},
						"malloc" : (...args) => { console.error("Not Implemented")},
						"realloc" : (...args) => { console.error("Not Implemented")},
						"free" : (...args) => { console.error("Not Implemented")},
						"memcpy" : (...args) => { console.error("Not Implemented")},
						"stbsp_sprintf" : (...args) => { console.error("Not Implemented")},
						"memcmp" : (...args) => { console.error("Not Implemented")},
						"write" : (...args) => { console.error("Not Implemented")},
					}
				}
		    );
		    console.log(instance.exports.julia_$(filename)(2));
		  }
		  init();
		</script>
	"""
end
