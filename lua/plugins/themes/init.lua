local specs = require("plugins.themes.catalog").load_specs()
specs[#specs + 1] = require("plugins.themes.themery")
return specs
