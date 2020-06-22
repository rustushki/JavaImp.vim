" -------------------------------------------------------------------  
" Mappings 
" -------------------------------------------------------------------  

command! -nargs=? JIX              call <SID>JavaImpQuickFix()
command! -nargs=? JI               call <SID>JavaImpInsert(1)
command! -nargs=? JavaImp          call <SID>JavaImpInsert(1)
command! -nargs=? JavaImpSilent    call <SID>JavaImpInsert(0)

command! -nargs=? JIG              call <SID>JavaImpGenerate()
command! -nargs=? JavaImpGenerate  call <SID>JavaImpGenerate()

command! -nargs=? JIS              call <SID>JavaImpSort()
command! -nargs=? JavaImpSort      call <SID>JavaImpSort()

command! -nargs=? JID              call <SID>JavaImpDoc()
command! -nargs=? JavaImpDoc       call <SID>JavaImpDoc()

command! -nargs=? JIF              call <SID>JavaImpFile(0)
command! -nargs=? JavaImpFile      call <SID>JavaImpFile(0)

command! -nargs=? JIFS             call <SID>JavaImpFile(1)
command! -nargs=? JavaImpFileSplit call <SID>JavaImpFile(1)

" -------------------------------------------------------------------  
" Default configuration 
" -------------------------------------------------------------------  

" Determine JavaImp's Installation Directory.
let s:pluginHome = expand("<sfile>:p:h:h")

if(has("unix"))
    let s:SL = "/"
elseif(has("win16") || has("win32") || has("win95") ||
            \has("dos16") || has("dos32") || has("os2"))
    let s:SL = "\\"
else
    let s:SL = "/"
endif

if !exists("g:JavaImpDataDir")
    let g:JavaImpDataDir = expand("$HOME") . s:SL . "vim" . s:SL . "JavaImp"
endif

if !exists("g:JavaImpClassList")
    let g:JavaImpClassList = g:JavaImpDataDir . s:SL . "JavaImp.txt"
endif

" Order import statements which match these regular expressions in the order
" of the expression.  The default setting sorts import statements with java.*
" first, then javax.*, then org.*, then com.*, and finally everything else
" alphabetically after that.  These settings emulate Eclipse's settings.
if !exists("g:JavaImpTopImports")
	let g:JavaImpTopImports = [
		\ 'java\..*',
		\ 'javax\..*',
		\ 'org\..*',
		\ 'com\..*'
		\ ]
endif

" Bottom Imports.
" Place these import statements after the middle import statements, and before
" static import statements (if they're configured to come last).
if !exists("g:JavaImpBottomImports")
	let g:JavaImpBottomImports = []
endif

" Put the Static Imports First if 1, otherwise put the Static Imports last.
" Defaults to 1.
if !exists("g:JavaImpStaticImportsFirst")
	let g:JavaImpStaticImportsFirst = 1
endif


" Deprecated
if !exists("g:JavaImpJarCache")
    let g:JavaImpJarCache = g:JavaImpDataDir . s:SL . "cache"
endif

if !exists("g:JavaImpSortRemoveEmpty")
    let g:JavaImpSortRemoveEmpty = 1
endif

" Note if the SortPkgSep is set, then you need to remove the empty lines.
if !exists("g:JavaImpSortPkgSep")
    if (g:JavaImpSortRemoveEmpty == 1)
        let g:JavaImpSortPkgSep = 2
    else
        let g:JavaImpSortPkgSep = 0
    endif
endif

if !exists("g:JavaImpPathSep")
    let g:JavaImpPathSep = ","
endif

if !exists("g:JavaImpDocViewer")
    let g:JavaImpDocViewer = "w3m"
endif

if !exists("g:JavaImpSpacesAfterGroups")
    let g:JavaImpSpacesAfterGroups = 0
endif

if !exists("g:JavaImpNewLineAtEnd")
    let g:JavaImpNewLineAtEnd = 0
endif

" -------------------------------------------------------------------  
" Generating the imports table
" -------------------------------------------------------------------  

"Generates the mapping file
function! <SID>JavaImpGenerate()
    if (<SID>JavaImpChkEnv() != 0)
        return
    endif
    " We would like to save the current buffer first:
    if expand("%") != '' 
        update
    endif
    cclose
    "Recursivly go through the directory and write to the temporary file.
    let impfile = tempname()
    " Save the current buffer number
    let currBuff = bufnr("%")
    silent exe "split ".impfile
    let currPaths = g:JavaImpPaths
    " See if currPaths has a separator at the end, if not, we add it.
        "echo "currPaths begin is " . currPaths
    if (match(currPaths, g:JavaImpPathSep . '$') == -1)
        let currPaths = currPaths . g:JavaImpPathSep
    endif

    while (currPaths != "" && currPaths !~ '^ *' . g:JavaImpPathSep . '$')
		" Cut off the first path from the delimeted list of paths to examine.
		let sepIdx = stridx(currPaths, g:JavaImpPathSep)
        let currPath = strpart(currPaths, 0, sepIdx)

		" Uncertain what this is doing.
		" currPath is the same before and after.
        let pkgDepth = substitute(currPath, '^.*{\(\d\+\)}.*$', '\1', '')
        let currPath = substitute(currPath, '^\(.*\){.*}.*', '\1', '')

        let headStr = ""
        while (pkgDepth != 0)
            let headStr = headStr . ":h"
            let pkgDepth = pkgDepth - 1
        endwhile

        let pathPrefix = fnamemodify(currPath, headStr)
        let currPkg = strpart(currPath, strlen(pathPrefix) + 1)

        echo "Searching in path (package): " . currPath . ' (' . currPkg .  ')'
        "echo "currPaths: ".currPaths
        let currPaths = strpart(currPaths, sepIdx + 1, strlen(currPaths) - sepIdx - 1)
        "echo "(".currPaths.")"
        call <SID>JavaImpAppendClass(currPath, currPkg)
    endwhile

    "silent exe "write! /tmp/raw"
    let classCount = line("$")

    " Formatting the file
    "echo "Formatting the file..." 
    1,$call <SID>JavaImpFormatList()
    "silent exe "write! /tmp/raw_formatted"

    " Sorting the file
    echo "Sorting the classes"
	%sort
    "silent exe "write! /tmp/raw_sorted"

    echo "Assuring uniqueness..." 
    1,$call <SID>CheesyUniqueness()
    let uniqueClassCount = line("$") - 1
    "silent exe "write! /tmp/raw_unique"

    " before we write to g:JavaImpClassList, close g:JavaImpClassList
    " exe "bwipeout ".g:JavaImpClassList (we do this because a user might
    " want to do a JavaImpGenerate after having been dissapointed that
    " his JavaImpInsert missed something... 
    if (bufexists(g:JavaImpClassList))
        silent exe "bwipeout! " g:JavaImpClassList
    endif

    silent exe "write!" g:JavaImpClassList
    cclose
    " Delete the temporary file
	silent exe "bwipeout! " impfile
    call delete(impfile)
    echo "Done.  Found " . classCount . " classes (". uniqueClassCount. " unique)"
endfunction

" The helper function to append a class entry in the class list
function! <SID>JavaImpAppendClass(cpath, relativeTo)
    " echo "Arguments " . a:cpath . " package is " . a:relativeTo
    if strlen(a:cpath) < 1 
        echo "Alert! Bug in JavaApppendClass (JavaImp.vim)"
        echo " - null cpath relativeTo ".a:relativeTo
        echo "(beats me... hack the source and figure it out)"
        " Base case... infinite loop protection
        return 0
    elseif (!isdirectory(a:cpath) && match(a:cpath, '\(\.class$\|\.java$\)') > -1)
        " oh good, we see a single entry like org/apache/xerces/bubba.java
        " just slap it on our tmp buffer
        if (a:relativeTo == "")
            call append(0, a:cpath)
        else
            call append(0, a:relativeTo)
        endif
    elseif (isdirectory(a:cpath))
        " Recursively fetch all Java files from the provided directory path.
        let l:javaList = glob(a:cpath . "/**/*.java", 1, 1) 
        let l:clssList = glob(a:cpath . "/**/*.class", 1, 1) 
        let l:list = l:javaList + l:clssList

        " Include a trailing slash so that we don't leave a slash at the
        " beginning of the fully qualified classname.
        let l:cpath = a:cpath . "/"

        " Add each matching file to the class index buffer.
        " The format of each entry will be akin to: org/apache/xerces/Bubba
        for l:filename in l:list
            let l:filename = substitute(l:filename, l:cpath, "", "g")
            call append(0, l:filename)
        endfor

        " Now that we have handled all java/class files, handle jars
        let l:jarList = glob(a:cpath . "/**/*.jar", 1, 1)

        for l:jar in l:jarList
            call <SID>JavaImpAppendClass(l:jar, a:relativeTo)
        endfor

        let l:jmplstList = glob(a:cpath . "/**/*.jmplst", 1, 1)
        for l:jmplst in l:jmplstList
            call <SID>JavaImpAppendClass(l:jmplst, a:relativeTo)
        endfor

    elseif (match(a:cpath, '\(\.jar$\)') > -1)
        " Check if the jar file exists, if not, we return immediately.
        if (!filereadable(a:cpath))
            echo "Skipping " . a:cpath . ". File does not exist."
            return 0
        endif
        " If we get a jar file, we first tries to match the timestamp of the
        " cache defined in g:JavaImpJarCache directory.  If the jar is newer,
        " then we would execute the jar command.  Otherwise, we just slap the
        " cached file to the buffer.
        "
        " The cached entries are organized in terms of the relativeTo path
        " with the '/' characters replaced with '_'.  For example, if you have
        " your jar in the directory /blah/lib/foo.jar, you'll have a cached
        " file called _blah_lib_foo.jmplst in your cache directory.
        
        let l:jarcache = expand(g:JavaImpJarCache)
        let l:jarcmd = 'jar -tf "'.a:cpath . '"'
        if (l:jarcache != "")
            let l:cachefile = substitute(a:cpath, '[ :\\/]',  "_", "g")
            let l:cachefile = substitute(l:cachefile, "jar$",  "jmplst", "")
            let l:jarcache = l:jarcache . s:SL . l:cachefile
            " Note that if l:jarcache does not exist, it'll return -1
            if (getftime(l:jarcache) < getftime(a:cpath))
                " jar file is newer
                " if we get a jar, just slap the jar -tf contents to the cache
                echo "  - Updating jar: " . fnamemodify(a:cpath, ":t") . "\n"
                let l:jarcmd = "!".l:jarcmd . " > \"" . escape(l:jarcache, '\\') . "\""
                silent execute l:jarcmd
                if (v:shell_error != 0)
                    echo "  - Error running the jar command: " . l:jarcmd
                endif
            else
                "echo "  - jar (cached): " . fnamemodify(a:cpath, ":t") . "\n"
            endif
            " Slap the cached content to the buffer
            silent execute "read " . l:jarcache
        else
            echo "  - Updating jar: " . fnamemodify(a:cpath, ":t") . "\n"
            " Always slap the output for the jar command to the file if cache
            " is turned off.
            silent execute "read !".l:jarcmd
        endif
    elseif (match(a:cpath, '\(\.jmplst$\)') > -1)
        " a jmplist is something i made up... it's basically the output of a jar -tf
        " operation.  Why is this useful?  
        " 1) to save time if there is a jar you read frequently (jar -tf is slow)
        " 2) because the java src.jar (for stuff like javax.swing)
        "    has everything prepended with a "src/", for example "src/javax/swing", so
        "    what i did was to run that through perl, stripping out the src/ and store
        "    the results in as java-1_3_1.jmplist in my .vim directory... 

        " we just insert its contents into the buffer
        "echo "  - jmplst: " . fnamemodify(a:cpath, ":t") . "\n"
        silent execute "read ".a:cpath
    endif
endfunction

" Converts the current line in the buffer from a java|class file pathname 
"  into a space delimited class package
" For example: 
"  /javax/swing/JPanel.java 
"  becomes:
"  JPanel javax.swing
" If the current line does not appear to contain a java|class file, 
" we blank it out (this is useful for non-bytecode entries in the 
" jar files, like gif files or META-INF)
function! <SID>JavaImpFormatList() 
    let l:currentLine = getline(".")

    " -- get the package name
    let l:subdirectory = fnamemodify(l:currentLine, ":h") 
    let l:packageName = substitute(l:subdirectory, "/", ".", "g")

    " -- get the class name 
    " this match string extracts the classname from a class path name
    " in other words, if you hand /javax/swing/JPanel.java, it would 
    " return in JPanel (as regexp var \1)
    let l:classExtensions = '\(\.class\|\.java\)'
    let l:matchClassName = match(l:currentLine, '[\\/]\([\$0-9A-Za-z_]*\)'.classExtensions.'$')
    if l:matchClassName > -1
        let l:matchClassName = l:matchClassName + 1 
        let l:className = strpart(l:currentLine, l:matchClassName)
        let l:className = substitute(l:className,  l:classExtensions, '', '')

		" TODO: It'd be better if we could handle the importing of inner
		" classes.
		"
        " subst '$' -> '.' for classes defined inside other classes
        " don't know if it will do anything useful, but at least it 
        " will be less incorrect than it was before
        let l:className = substitute(l:className, '\$', '.', 'g')
        call setline(".", l:className." ".l:packageName.".".l:className)
    else
        " if we didn't find something which looks like a class, we
        " blank out this line (sorting will pick this up later)
        call setline(".", "")
    endif
endfunction

" -------------------------------------------------------------------  
" Inserting imports 
" -------------------------------------------------------------------  

" Inserts the import statement of the class specified under the cursor in the
" current .java file.
"
" If there is a duplicated entry for the classname, it'll insert the entry as
" comments (starting with "//")
"
" If the entry already exists (specified in an import statement in the current
" file), this will do nothing.
"
" pass 0 for verboseMode if you want fewer updates of what this function is 
"  doing, or 1 for normal verbosity
" (silence is interesting if you're scripting the use of JavaImpInsert...
"  for example, i have a script that runs JavaImpInsert on all the 
"  class not found errors)
function! <SID>JavaImpInsert(verboseMode)
    if (<SID>JavaImpChkEnv() != 0)
        return
    endif
    if a:verboseMode
        let verbosity = ""
    else
        let verbosity = "silent"
    end

    " Write the current buffer first (if we have to).  Note that we only want
    " to do this if the current buffer is named.
    if expand("%") != '' 
        exec verbosity "update"
    endif

    " choose the current word for the class
    let className = expand("<cword>")
    let fullClassName = <SID>JavaImpCurrFullName(className)

    if (fullClassName != "")
        if verbosity != "silent"
            echo "Import for " . className . " found in this file."
        endif
    else 
        let fullClassName = <SID>JavaImpFindFullName(className)
        if (fullClassName == "")
            if ! a:verboseMode
                echo className." not found (you should update the class map file)"
            else
                echo "Can not find any class that matches " . className . "."
                let input = confirm("Do you want to update the class map file?", "&Yes\n&No", 2)
                if (input == 1)
                    call <SID>JavaImpGenerate()
                    return
                endif
            endif
        else
            let importLine = "import " . fullClassName . ";"
            " Split before we jump
            split

            let hasImport = <SID>JavaImpGotoLast()
            let importLoc = line('.')

            let hasPackage = <SID>JavaImpGotoPackage()
            if (hasPackage == 1)
                let pkgLoc = line('.')
                let pkgPat = '^\s*package\s\+\(\%(\w\+\.\)*\w\+\)\s*;.*$'
                let pkg = substitute(getline(pkgLoc), pkgPat, '\1', '')

                " Check to see if the class is in this package, we won't
                " need an import.
                if (fullClassName == (pkg . '.' . className))
                    let importLoc = -1
                else
                    if (hasImport == 0)
                        " Add an extra blank line after the package before
                        " the import
                        exec verbosity 'call append(pkgLoc, "")'
                        let importLoc = pkgLoc + 1
                    endif
                endif
            elseif (hasImport == 0)
                let importLoc = 0
            endif

            exec verbosity 'call append(importLoc, importLine)'

            if a:verboseMode
                if (importLoc >= 0)
                    echo "Inserted " . fullClassName . " for " . className 
                else
                    echo "Import unneeded (same package): " . fullClassName
                endif
            endif 

            " go back to the old location
            close

        endif
    endif
endfunction

" Given a classname, try to search the current file for the import statement.
" If found, it'll return the fully qualify classname.  Otherwise, it'll return
" an empty string.
function! <SID>JavaImpCurrFullName(className)
    let pattern = '^\s*import\s\s*.*[.]' . a:className . '\s*;'
    " Split and jump
    split
    " First search for the className in an import statement
    normal G$
    if (search(pattern, "w") != 0)
        " We are on that import line now, try fetching the full className:
        let imp = substitute(getline("."), '^\s*import\s\s*\(.*[.]' . a:className . '\)\s*;', '\1', "")
        " close the window
        close
        return imp
    else
        close
        return ""
    endif
endfunction

" Given a classname, try to search the current file for the import statement.
" If found, it'll return the fully qualify classname.  If not found, it'll try
" to search the import list for the match.
function! <SID>JavaImpFindFullName(className)
    let fcn = <SID>JavaImpCurrFullName(a:className)
    if (fcn != "") 
        return fcn
    endif
    " We didn't find a preexisting import... that means
    " there is work to do

    " notice that we switch to the JavaImpClassList buffer 
    " (or load the file if needed)
    let icl = expand(g:JavaImpClassList)
    if (filereadable(icl))
        silent exe "split " . icl
    else
        echo "Can not load the class map file " . icl . "."
        return ""
    endif
    let importLine = ""
    normal G$

    let flags = "w"
    let firstImport = 0
    let importCtr = 0
    let pattern = '^' . a:className . ' '
    let firstFullPackage = ""
    while (search(pattern, flags) > 0)
        let importCtr = importCtr + 1
        let fullPackage = substitute(getline("."), '\S* \(.*\)$', '\1', "")
        let importLine = importLine . fullPackage . "\n"
        let flags = "W"
    endwhile
    " Loading back the old file
    close
    if (importCtr == 0)
        return ""
    else
        let pickedImport = <SID>JavaImpChooseImport(importCtr, a:className, importLine)
        return pickedImport
    endif
endfunction

" -------------------------------------------------------------------  
" Choosing and caching imports 
" -------------------------------------------------------------------  

" Check with the choice cache and determine the final order of the import
" list.
" The choice cache is a file with the following format:
" [className1] [most recently used class] [2nd most recently used class] ...
" [className2] [most recently used class] [2nd most recently used class] ...
" ...
"
" imports and the return list consists of fully-qualified classes separated by
" \n.  This function will list the imports list in the order specified by the
" choice cache file
"
" IMPORTANT: if the choice is not available in the cache, this returns
" empty string, not the imports
function! <SID>JavaImpMakeChoice(imctr, className, imports)
    let jicc = expand(g:JavaImpDataDir) . s:SL . "choices.txt"
    if !filereadable(jicc)
        return ""
    endif
    silent exe "split " . jicc
    let flags = "w"
    let pattern = '^' . a:className . ' '
    if (search(pattern, flags) > 0)
        let l = substitute(getline("."), '^\S* \(.*\)', '\1', "")
        close
        return <SID>JavaImpOrderChoice(a:imctr, l, a:imports)
    else
        close
        return ""
    endif
endfunction

" Order the imports with the cacheLine and returns the list.
function! <SID>JavaImpOrderChoice(imctr, cacheLine, imports)
    " we construct the imports so we can test for <space>classname<space>
    let il = " " . substitute(a:imports, "\n", " ", "g") . " "
    "echo "orig: " . a:imports
    "echo "il: " . il
    let rtn = " "
    " We first construct check each entry in the cacheLine to see if it's in
    " the imports list, if so, we add it to the final list.
    let cl = a:cacheLine . " "
    while (cl !~ '^ *$')
        let sepIdx = stridx(cl, " ")
        let cls = strpart(cl, 0, sepIdx)
        let pat = " " . cls . " "
        if (match(il, pat) >= 0)
            let rtn = rtn . cls . " "
        endif
        let cl = strpart(cl, sepIdx + 1)
    endwhile
    "echo "cache: " . rtn
    " at this point we need to add the remaining imports in the rtn list.
    " get rid of the beginning space
    let mil = strpart(il, 1)
    "echo "mil: " . mil
    while (mil !~ '^ *$')
        let sepIdx = stridx(mil, " ")
        let cls = strpart(mil, 0, sepIdx)
        let pat = " " . escape(cls, '.') . " "
        " we add to the list if only it's not in there.
        if (match(rtn, pat) < 0)
            let rtn = rtn . cls . " "
        endif
        let mil = strpart(mil, sepIdx + 1)
    endwhile
    " rid the head space
    let rtn = strpart(rtn, 1)
    let rtn = substitute(rtn, " ", "\n", "g")
    "echo "return : " . rtn
    return rtn
endfunction

" Save the import to the cache file.
function! <SID>JavaImpSaveChoice(className, imports, selected)
    let im = substitute(a:imports, "\n", " ", "g")
    " Note that we remove the selected first
    let spat = a:selected . " "
    let spat = escape(spat, '.')
    let im = substitute(im, spat, "", "g")

    let jicc = expand(g:JavaImpDataDir) . s:SL . "choices.txt"
    silent exe "split " . jicc
    let flags = "w"
    let pattern = '^' . a:className . ' '
    let l = a:className . " " . a:selected . " " . im
    if (search(pattern, flags) > 0)
        " we found it, replace the line.
        call setline(".", l)
    else
        " we couldn't found it, so we just add the choices
        call append(0, l)
    endif

    silent update
    close
endfunction

" Choose the import if there's multiple of them.  Returns the selected import
" class.
function! <SID>JavaImpChooseImport(imctr, className, imports)
    let imps = <SID>JavaImpMakeChoice(a:imctr, a:className, a:imports)
    let uncached = (imps == "")
    if uncached
        let imps = a:imports
        let simps = a:imports
        if (a:imctr > 1)
            let imps = "[No previous choice.  Please pick one from below...]\n".imps
        endif
    else
        let simps = imps
    endif

    let choice = 0 
    if (a:imctr > 1) 
      " if the item had not been cached, we force the user to make
      " a choice, rather than letting her choose the default
      let choice = <SID>JavaImpDisplayChoices(imps, a:className)
      " if the choice is not cached, we don't want the user to
      " simply pick anything because he is hitting enter all the
      " time so we loop around he picks something which isn't the
      " default (earlier on, we set the default to some nonsense
      " string)
      while (uncached && choice == 0) 
        let choice = <SID>JavaImpDisplayChoices(imps, a:className)
      endwhile
    endif

    " If cached, since we inserted the banner, we need to subtract the choice
    " by one:
    if (uncached && choice > 0)
        let choice = choice - 1
    endif

    " We run through the string again to pick the choice from the list
    " First reset the counter
    let ctr = 0
    let imps = simps
    while (imps != "" && imps !~ '^ *\n$')
        let sepIdx = stridx(imps, "\n")
        " Gets the substring exluding the newline
        let imp = strpart(imps, 0, sepIdx)
        if (ctr == choice)
            " We found it, we should update the choices
            "echo "save choice simps:" . simps . " imp: " . imp
            call <SID>JavaImpSaveChoice(a:className, simps, imp)
            return imp
        endif
        let ctr = ctr + 1
        let imps = strpart(imps, sepIdx + 1, strlen(imps) - sepIdx - 1)
    endwhile
    " should not get here...
    echo "warning: should-not-get here reached in JavaImpMakeChoice"
    return 
endfunction

function! <SID>JavaImpDisplayChoices(imps, className)
    let imps = a:imps
    let simps = imps
    let ctr = 0
    let choice = 0
    let cfmstr = ""
    let questStr =  "Multiple matches for " . a:className . ". Your choice?\n"
    while (imps != "" && imps !~ '^ *\n$')
        let sepIdx = stridx(imps, "\n")
        " Gets the substring exluding the newline
        let imp = strpart(imps, 0, sepIdx)
        let questStr = questStr . "(" . ctr . ") " . imp . "\n"
        let cfmstr = cfmstr . "&" . ctr . "\n"
        let ctr = ctr + 1
        let imps = strpart(imps, sepIdx + 1, strlen(imps) - sepIdx - 1)
    endwhile

    if (ctr <= 10)
        " Note that we need to get rid of the ending "\n" for it'll give
        " an extra choice in the GUI
        let cfmstr = strpart(cfmstr, 0, strlen(cfmstr) - 1)
        let choice = confirm(questStr, cfmstr, 0)
        " Note that confirms goes from 1 to 10, so if the result is not 0,
        " we need to subtract one
        if (choice != 0)
            let choice = choice - 1
        endif
    else
        let choice = input(questStr)
    endif

    return choice
endfunction

" -------------------------------------------------------------------  
" Sorting 
" -------------------------------------------------------------------  

" Sort the import statements in the current file.
function! <SID>JavaImpSort()
    if has('python3')
    	execute "py3file " . s:pluginHome . "/pythonx/jis.py"
    elseif has('python')
    	execute "pyfile " . s:pluginHome . "/pythonx/jis.py"
    else
        echom 'Sorting failed: No python support'
    endif
endfunction

" Place Sorted Static Imports either before or after the normal imports
" depending on g:JavaImpStaticImportsFirst.
function! <SID>JavaImpPlaceSortedStaticImports()
	" Find the Range of Static Imports
	if (<SID>JavaImpFindFirstStaticImport() > 0)
		let firstStaticImp = line(".")
		call <SID>JavaImpFindLastStaticImport()
		let lastStaticImp = line(".")

		" Remove the block of Static Imports.
		execute firstStaticImp . "," . lastStaticImp . "delete"

		" Place the cursor before the Normal Imports.
		if g:JavaImpStaticImportsFirst == 1
			" Find the Line which should contain the first import.
			if (<SID>JavaImpGotoPackage() == 0)
				normal! ggP
			else
				normal! jp
			endif


		" Otherwise, place the cursor after the Normal Imports.
		else
			" Paste in the Static Imports after the last import or at the top
			" of the file if no other imports.
			if (<SID>JavaImpGotoLast() <= 0)
				if (<SID>JavaImpGotoPackage() == 0)
					normal! ggP
				else
					normal! jp
				endif
			else
				normal! p
			endif
		endif

	endif
endfunction

" -------------------------------------------------------------------  
" Inserting spaces between packages 
" -------------------------------------------------------------------  

" Given a sorted range, we would like to add a new line (do a 'O')
" to seperate sections of packages.  The depth argument controls
" what we treat as a seperate section.
"
" Consider the following: 
" -----
"  import java.util.TreeSet;
"  import java.util.Vector;
"  import org.apache.log4j.Logger;
"  import org.apache.log4j.spi.LoggerFactory;
"  import org.exolab.castor.xml.Marshaller;
" -----
"
" With a depth of 1, this becomes
" -----
"  import java.util.TreeSet;
"  import java.util.Vector;

"  import org.apache.log4j.Logger;
"  import org.apache.log4j.spi.LoggerFactory;
"  import org.exolab.castor.xml.Marshaller;
" -----

" With a depth of 2, it becomes
" ----
"  import java.util.TreeSet;
"  import java.util.Vector;
"
"  import org.apache.log4j.Logger;
"  import org.apache.log4j.spi.LoggerFactory;
"
"  import org.exolab.castor.xml.Marshaller;
" ----
" Depth should be >= 1, but don't set it too high, or else this function
" will split everything up.  The recommended depth setting is "2"
function! <SID>JavaImpAddPkgSep(fromLine, toLine, depth)
    "echo "fromLine: " . a:fromLine . " toLine: " . a:toLine." depth:".a:depth
    if (a:depth <= 0) 
      return
    endif  
      
    let cline = a:fromLine
    let endline = a:toLine
    let lastPkg = <SID>JavaImpGetSubPkg(getline(cline), a:depth)

    let cline = cline + 1
    while (cline <= endline)
        let thisPkg = <SID>JavaImpGetSubPkg(getline(cline), a:depth)
        
        " If last package does not equals to this package, append a line
        if (lastPkg != thisPkg)
            "echo "last: " . lastPkg . " this: " . thisPkg
            call append(cline - 1, "")
            let endline = endline + 1
            let cline = cline + 1
        endif
        let lastPkg = thisPkg
        let cline = cline + 1
    endwhile
endfunction

" Returns the full path of the Java source file or JavaDoc.
"
" Set 'ext' to:
"  .html - for JavaDoc.
"  .java - for Java files.
"
" @param basePath - the base path to search for the class.
" @param fullClassName - fully qualified class name
" @param ext - extension to search for.
function! <SID>JavaImpGetFile(basePath, fullClassName, ext)
    " Convert the '.' to '/'.
    let df = substitute(a:fullClassName, '\.', '/', "g")

	" Construct the full path to the possible file.
    let h = df . a:ext
    let l:rtn = expand(a:basePath . "/" . h)

	" If the file is not readable, return an empty string.
	if filereadable(rtn) == 0
		let l:rtn = ""
	endif
	return l:rtn
endfunction

" View the doc
function! <SID>JavaImpViewDoc(f)
    let cmd = '!' . g:JavaImpDocViewer . ' "' . a:f . '"'
    silent execute cmd
    " We need to redraw after we quit, for things may not refresh correctly
    redraw!
endfunction

" -------------------------------------------------------------------  
" Java Source Viewing
" -------------------------------------------------------------------  
function! <SID>JavaImpFile(doSplit)
    " We would like to save the current buffer first:
    if expand("%") != '' 
        update
    endif

	" Class Name to search for is the Current Word.
    let className = expand("<cword>")

	" Find the fully qualified classname for this class.
    let fullClassName = <SID>JavaImpFindFullName(className)
    if (fullClassName == "")
        echo "Can't find class " . className
        return 

	" Otherwise, search for the class.
    else
        let currPaths = g:JavaImpPaths

        " See if currPaths has a separator at the end, if not, we add it.
        if (match(currPaths, g:JavaImpPathSep . '$') == -1)
            let currPaths = currPaths . g:JavaImpPathSep
        endif

        while (currPaths != "" && currPaths !~ '^ *' . g:JavaImpPathSep . '$')
			" Find First Separator (this marks the end of the Next Path).
            let sepIdx = stridx(currPaths, g:JavaImpPathSep)

			" Retrieve the Next Path.
            let currPath = strpart(currPaths, 0, sepIdx)

            " Chop off the Next Path--this leaves only the remaining paths to
			" search.
            let currPaths = strpart(currPaths, sepIdx + 1, strlen(currPaths) - sepIdx - 1)

            if (isdirectory(currPath))
                let f = <SID>JavaImpGetFile(currPath, fullClassName, ".java")
                if (f != "")
                    if (a:doSplit == 1)
                        split
                    endif
                    exec "edit " . f
                    return
                endif
            endif
        endwhile
        echo "Can not find " . fullClassName . " in g:JavaImpPaths"
    endif
endfunction

" -------------------------------------------------------------------  
" Java Doc Viewing
" -------------------------------------------------------------------  
function! <SID>JavaImpDoc()
    if (!exists("g:JavaImpDocPaths"))
        echo "Error: g:JavaImpDocPaths not set.  Please see the documentation for details."
        return
    endif

    " choose the current word for the class
    let className = expand("<cword>")
    let fullClassName = <SID>JavaImpFindFullName(className)
    if (fullClassName == "")
        return 
    endif

    let currPaths = g:JavaImpDocPaths
    " See if currPaths has a separator at the end, if not, we add it.
    if (match(currPaths, g:JavaImpPathSep . '$') == -1)
        let currPaths = currPaths . g:JavaImpPathSep
    endif
    while (currPaths != "" && currPaths !~ '^ *' . g:JavaImpPathSep . '$')
        let sepIdx = stridx(currPaths, g:JavaImpPathSep)
        " Gets the substring exluding the newline
        let currPath = strpart(currPaths, 0, sepIdx)
        "echo "Searching in path: " . currPath
        let currPaths = strpart(currPaths, sepIdx + 1, strlen(currPaths) - sepIdx - 1)
        let docFile = <SID>JavaImpGetFile(currPath, fullClassName, ".html")
	    if (filereadable(docFile))
            call <SID>JavaImpViewDoc(docFile)
            return
	    endif
    endwhile
    echo "JavaDoc not found in g:JavaImpDocPaths for class " . fullClassName
    return
endfunction

" -------------------------------------------------------------------  
" Quickfix 
" -------------------------------------------------------------------  

" Taken from Eric Kow's dev script...
"
" This function will try to open your error window, given that you have run Ant
" and the quickfix windows contains unresolved symbol error, will fix all of
" them for you automatically!
function! <SID>JavaImpQuickFix()
    if (<SID>JavaImpChkEnv() != 0)
        return
    endif
    " FIXME... we should figure out if there are no errors and
    " quit gracefully, rather than let vim do its error thing and
    " figure out where to stop
    crewind
    cn
    cn 
    copen
    let l:nextStr = getline(".")
    echo l:nextStr
    let l:currentStr = ''

    crewind
    " we use the cn command to advance down the quickfix list until
    " we've hit the last error 
    while match(l:nextStr,'|[0-9]\+ col [0-9]\+|') > -1 
        " jump to the quickfix error window
        cnext
        copen
        let l:currentLine = line(".")
        let l:currentStr=getline(l:currentLine)
        let l:nextStr=getline(l:currentLine + 1)
        
        if (match(l:currentStr, 'cannot resolve symbol$') > -1 ||
                    \ match(l:currentStr, 'Class .* not found.$') > -1 ||
                    \ match(l:currentStr, 'Undefined variable or class name: ') > -1)

            " get the filename (we don't use this for the sort, 
            " but later on when we want to sort a file's after
            " imports after inserting all the ones we know of
            let l:nextFilename = substitute(l:nextStr,  '|.*$','','g')
            let l:oldFilename = substitute(l:currentStr,'|.*$','','g')
            
            " jump to where the error occurred, and fix it
            cc
            call <SID>JavaImpInsert(0)

            " since we're still in the buffer, if the next line looks
            " like a different file (or maybe the end-of-errors), sort
            " this file's import statements
            if l:nextFilename != l:oldFilename 
                call <SID>JavaImpSort()
            endif
        endif

        " this is where the loop checking happens
    endwhile
endfunction

" -------------------------------------------------------------------  
" (Helpers) Vim-sort for those of us who don't have unix or cygwin 
" -------------------------------------------------------------------  

" -------------------------------------------------------------------  
" (Helpers) Goto...
" -------------------------------------------------------------------  

" Go to the package declaration
function! <SID>JavaImpGotoPackage()
    " First search for the className in an import statement
    normal G$
    let flags = "w"
    let pattern = '^\s*package\s\s*.*;'
    if (search(pattern, flags) == 0)
        return 0
    else
        return 1
    endif
endfunction

" Go to the last import statement that it can find.  Returns 1 if an import is
" found, returns 0 if not.
function! <SID>JavaImpGotoLast()
	return <SID>JavaImpGotoFirstMatchingImport('', 'b')
endfunction

" Go to the last static import statement that it can find.  Returns 1 if an
" import is found, returns 0 if not.
function! <SID>JavaImpFindLastStaticImport()
	return <SID>JavaImpGotoFirstMatchingImport('static\s\s*', 'b')
endfunction
"
" Go to the first static import statement that it can find.  Returns 1 if an
" import is found, returns 0 if not.
function! <SID>JavaImpFindFirstStaticImport()
	return <SID>JavaImpGotoFirstMatchingImport('static\s\s*', 'w')
endfunction

function! <SID>JavaImpGotoFirstMatchingImport(pattern, flags)
	normal G$
	let pattern = '^\s*import\s\s*'
	if (a:pattern != "")
		let pattern = l:pattern . a:pattern
	endif
	let pattern = l:pattern . '.*;'
    return (search(l:pattern, a:flags) > 0)
endfunction

" -------------------------------------------------------------------  
" (Helpers) Miscellaneous 
" -------------------------------------------------------------------  

" Removes all duplicate entries from a sorted buffer
" preserves the order of the buffer and runs in o(n) time
function! <SID>CheesyUniqueness() range
    let l:storedStr = getline(1)
    let l:currentLine = 2 
    let l:lastLine = a:lastline
    "echo "starting with l:storedStr ".l:storedStr.", l:currentLine ".l:currentLine.", l:lastLine".lastLine
    while l:currentLine < l:lastLine 
        let l:currentStr = getline(l:currentLine)
        if l:currentStr == l:storedStr
            "echo "deleting line ".l:currentLine
            exe l:currentLine."delete"
            " note that we do NOT advance the currentLine counter here
            " because where currentLine is is what was once the next 
            " line, but what we do have to do is to decrement what we 
            " treat as the last line
            let l:lastLine = l:lastLine - 1
        else
            let l:storedStr = l:currentStr
            let l:currentLine = l:currentLine + 1
            "echo "set new stored Str to ".l:storedStr
        endif
    endwhile 
endfunction

" -------------------------------------------------------------------  
" (Helpers) Making sure directory is set up 
" -------------------------------------------------------------------  

" Returns 0 if the directory is created successfully.  Returns non-zero
" otherwise.
function! <SID>JavaImpCfmMakeDir(dir)
    if (! isdirectory(a:dir))
        let input = confirm("Do you want to create the directory " . a:dir . "?", "&Create\n&No", 1)
        if (input == 1)
            return <SID>JavaImpMakeDir(a:dir)
        else
            echo "Operation aborted."
            return 1
        endif
    endif
endfunction

function! <SID>JavaImpMakeDir(dir)
    if(has("unix"))
        let cmd = "mkdir -p " . a:dir
    elseif(has("win16") || has("win32") || has("win95") ||
                \has("dos16") || has("dos32") || has("os2"))
        let cmd = "mkdir \"" . a:dir . "\""
    else
        return 1
    endif
    call system(cmd)
    let rc = v:shell_error
    "echo "calling " . cmd
    return rc
endfunction

" Check and make sure the directories are set up correctly.  Otherwise, create
" the dir or complain.
function! <SID>JavaImpChkEnv()
    " Check if the g:JavaImpPaths is set:
    if (!exists("g:JavaImpPaths"))
        echo "You have not set the g:JavaImpPaths variable.  Pleae see documentation for details."
        return 1
    endif
    let rc = <SID>JavaImpCfmMakeDir(g:JavaImpDataDir)
    if (rc != 0)
        echo "Error creating directory: " . g:JavaImpDataDir
        return rc
    endif
    "echo "Created directory: " . g:JavaImpDataDir
    let rc = <SID>JavaImpCfmMakeDir(g:JavaImpJarCache)
    if (rc != 0)
        echo "Error creating directory: " . g:JavaImpJarCache
        return rc
    endif
    "echo "Created directory: " . g:JavaImpJarCache
    return 0
endfunction

" Returns the (sub) package name of an import " statement.  
"
" Consider the string "import foo.bar.Frobnicability;"
"
" If depth is 1, this returns "foo"
" If depth is 2, this returns "foo.bar"
" If depth >= 3, this returns "foo.bar.Frobnicability"
function! <SID>JavaImpGetSubPkg(importStr,depth) 
    " set up the match/grep command 
    let subpkgStr = '[^.]\{-}\.'
    let pkgMatch = '\s*import\s*.*\.[^.]*;$'
    let pkgGrep = '\s*import\s*\('
    let curDepth = a:depth
    " we tack on a:depth extra subpackage to the end of the match
    " and grep expressions 
    while (curDepth > 0) 
      let pkgGrep = pkgGrep.subpkgStr
      let curDepth = curDepth - 1
    endwhile
    let pkgGrep = pkgGrep.'\)'.'.*;$'
    " echo pkgGrep
    
    if (match(a:importStr, pkgMatch) == -1)
        let lastPkg = ""
    else
        let lastPkg = substitute(a:importStr, pkgGrep, '\1', "")
    endif

    " echo a:depth.' gives us '.lastPkg
    return lastPkg
endfunction
