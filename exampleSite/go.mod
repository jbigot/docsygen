module github.com/jbigot/docsygen/exampleSite

go 1.12

require (
	github.com/docsy/docsy/theme v0.18.0 // indirect
	github.com/jbigot/docsygen v0.0.0 // indirect
)

// The example site always uses the docsygen module from this repository.
replace github.com/jbigot/docsygen => ../
