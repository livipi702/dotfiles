return {
	filetypes = {
		"html",
		"css",
		"javascriptreact",
		"typescriptreact",
		"ejs",
	},
	root_markers = {
		{
			"tailwind.config.js",
			"tailwind.config.ts",
			"tailwind.config.cjs",
			"tailwind.config.mjs",
			"tailwind.config.mts",
		},
		".git",
	},
	settings = {
		tailwindCSS = {
			classAttributes = {
				"class",
				"className",
				"class:list",
				"classList",
				"ngClass",
			},
			includeLanguages = {
				ejs = "html",
				html = "html",
				javascript = "javascript",
				javascriptreact = "javascript",
				typescript = "typescript",
				typescriptreact = "typescript",
			},
			lint = {
				cssConflict = "warning",
				invalidApply = "error",
				invalidScreen = "error",
				invalidVariant = "error",
				recommendedVariantOrder = "warning",
			},
			validate = true,
		},
	},
}
