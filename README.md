## How does this work?
- Make sure to read the documentation of our poison theme! https://themes.gohugo.io/themes/poison/
- Poison Demo site https://poison.lukeorth.com/
- Code of the poison demo site https://github.com/lukeorth/poison-demo-site/tree/master
- Code of the poison theme https://github.com/lukeorth/poison/tree/master

## Dependencies


- The idea is to have a separate directory for unfinished WIP stuff
  - The public version of the website will not include that directory

- [Poison theme](https://github.com/lukeorth/poison)
  - `git submodule add https://github.com/lukeorth/poison.git themes/poison`
  - `git submodule update --recursive --remote`


## Hugo Stuff
- Draft articles are not normally published, unless the relevant cli flag is passed. This also causes errors when linking to them


## Poison Template
- The css files in `assets/css` of the poison theme are combined in the file `layouts/partials/head/stylesheets.html` the lower files override the higher files, so poison overrides the others, and the custom.css file can be used for further customisation. The properties are additive, unless the same property is redefined, in which case it will replace the earlier one


## Character Rules
https://de.wikipedia.org/wiki/Langes_s#Regeln_von_1901
