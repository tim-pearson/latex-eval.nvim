if vim.g.loaded_latex_eval == 1 then
  return
end
vim.g.loaded_latex_eval = 1

if vim.g.latex_eval_configured ~= 1 then
  require("latex-eval").setup()
end
