
`.Site.IsServer` returns whether the Site is run inside of the inbuilt hugo webserver or not


```
{{ if site.IsServer -}}
{{ print "<!-- Debug info only available when running a local server -->" | safeHTML }}
<pre>{{ .Site.Sections | jsonify (dict "indent" "  ") }}<pre>
{{ print "<!-- End debug info -->" | safeHTML -}}
{{- end }}
```


Just output stuff to look at it
```
<!-- BEGIN DEBUG -->
{{ lower .Title }}
{{ $expectedSection }}
{{ $menu_item.Name }}
<!-- END DEBUG -->
```

https://write.rog.gr/writing/various-ways-to-debug-in-hugo/
