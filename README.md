
Install Instructions
====================
   * Install `stack` build tool for Haskell
     * `curl -sSL https://get.haskellstack.org/ | sh`
	 * See the web page for details: `https://docs.haskellstack.org/en/stable/README/`
	 
   * Build policytool:
     * `cd policy-tool`
       * Need to be on internet when you 'stack build' policy tool the first time to be
         able to download lots of libraries
     * `stack build`
	 * policy-tool gets installed into ~/.local/bin

   * add `~/.local/bin' to your path


