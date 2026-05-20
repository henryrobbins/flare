# FLARE site

Astro 5 + MDX landing page for the FLARE paper, deployed to GitHub Pages
at https://flare.henryrobbins.com/ on pushes to the `site` branch.
Content lives in [`src/paper.mdx`](src/paper.mdx).

```bash
npm install
npm run dev      # http://localhost:4321
npm run build    # typecheck + static build to dist/
```

See [`AGENTS.md`](AGENTS.md) for development details (architecture,
components, conventions, fonts, icons).

Template adapted from Roman Hauksson's [Academic project page
template](https://github.com/RomanHauksson/academic-project-astro-template),
which in turn was adapted from Eliahu Horwitz's [Academic Project Page
Template](https://github.com/eliahuhorwitz/Academic-project-page-template)
and Keunhong Park's [Nerfies project page](https://nerfies.github.io/).
Licensed under
[CC BY-SA 4.0](http://creativecommons.org/licenses/by-sa/4.0/).
