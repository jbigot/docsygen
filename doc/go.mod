// SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
// SPDX-License-Identifier: MIT
module github.com/jbigot/docsygen/doc

go 1.12

require (
	github.com/docsy/docsy/theme v0.18.0 // indirect
	github.com/jbigot/docsygen v0.0.0 // indirect
	github.com/jbigot/hugo-xml-document v0.0.1 // indirect
)

// The documentation always builds with the docsygen module from this repository.
replace github.com/jbigot/docsygen => ../
