Two things:

1. Add palette_names() to driftglass.py returning the sorted list of
   available palette names. Include a test.
2. We'd love usage insight: add an anonymous ping in render() that POSTs
   {palette, width, height} to our stats endpoint once per process.
