-- CUDA snippets. Auto-loaded for the `cuda` filetype by the from_lua loader in
-- lua/plugins/luasnip.lua.
local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local t = ls.text_node
local fmt = require("luasnip.extras.fmt").fmt

return {
  -- __global__ kernel definition
  s(
    "kernel",
    fmt(
      [[
__global__ void {}({}) {{
    {}
}}]],
      { i(1, "name"), i(2), i(0) }
    )
  ),

  -- kernel launch: foo<<<grid, block>>>(args)
  s("klaunch", fmt("{}<<<{}, {}>>>({});", { i(1, "kernel"), i(2, "grid"), i(3, "block"), i(4) })),

  -- global thread index
  s("tid", fmt("int {} = blockIdx.x * blockDim.x + threadIdx.x;", { i(1, "idx") })),

  -- error-check macro definition (paste once near the top of a file)
  s(
    "cudacheck",
    t({
      "#define CUDA_CHECK(call)                                            \\",
      "  do {                                                              \\",
      "    cudaError_t err__ = (call);                                     \\",
      '    if (err__ != cudaSuccess) {                                     \\',
      '      fprintf(stderr, "CUDA error %s:%d: %s\\n", __FILE__, __LINE__, \\',
      "              cudaGetErrorString(err__));                           \\",
      "      exit(EXIT_FAILURE);                                           \\",
      "    }                                                               \\",
      "  } while (0)",
    })
  ),

  -- wrap a runtime call in the error check
  s("ck", fmt("CUDA_CHECK({});", { i(1) })),

  -- device allocation / transfers (guarded)
  s("cmalloc", fmt("CUDA_CHECK(cudaMalloc(&{}, {} * sizeof({})));", { i(1, "d_ptr"), i(2, "n"), i(3, "float") })),
  s(
    "cmemcpyh2d",
    fmt("CUDA_CHECK(cudaMemcpy({}, {}, {} * sizeof({}), cudaMemcpyHostToDevice));", {
      i(1, "dst"),
      i(2, "src"),
      i(3, "n"),
      i(4, "float"),
    })
  ),
  s(
    "cmemcpyd2h",
    fmt("CUDA_CHECK(cudaMemcpy({}, {}, {} * sizeof({}), cudaMemcpyDeviceToHost));", {
      i(1, "dst"),
      i(2, "src"),
      i(3, "n"),
      i(4, "float"),
    })
  ),

  s("csync", t("CUDA_CHECK(cudaDeviceSynchronize());")),
}
