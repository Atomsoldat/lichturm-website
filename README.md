## Creating more content
```
hugo new content content/posts/123_abc.de.md
```


## Dependencies

- [Poison theme](https://github.com/lukeorth/poison) (We are using our [own fork](https://github.com/Atomsoldat/poison))
  - `git submodule add https://github.com/lukeorth/poison.git themes/poison`
  - `git submodule update --recursive --remote`


## Poison Template
- The css files in `assets/css` of the poison theme are combined in the file `layouts/partials/head/stylesheets.html` the lower files override the higher files, so poison overrides the others, and the custom.css file can be used for further customisation. The properties are additive, unless the same property is redefined, in which case it will replace the earlier one
