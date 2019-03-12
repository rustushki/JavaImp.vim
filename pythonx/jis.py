import vim
import re

class Sorter:
    IMPORT_BEGIN = "^\s*import\s+" 

    def __init__(self):
        # Initialize lists
        self._importTopImpList = []
        self._importMiddleList = []
        self._importBottomList = []
        self._importStaticList = []
        self._topInd = 0
        self._middleInd = 0
        self._bottomEnd = 0

        # Read in Configuration Options
        self._depth = int(vim.eval("g:JavaImpSortPkgSep"))
        self._topImports = vim.eval("g:JavaImpTopImports")
        self._bottomImports = vim.eval("g:JavaImpBottomImports")
        self._staticFirst = int(vim.eval("g:JavaImpStaticImportsFirst"))
        self._spacesAfterGroups = int(vim.eval("g:JavaImpSpacesAfterGroups"))
        self._newLineAtEnd = int(vim.eval("g:JavaImpNewLineAtEnd"))
        self._sortLongerSecond = int(vim.eval("g:JavaImpSortLongerSecond"))

        # Initialize Import Statement Range
        self._rangeStart = -1
        self._rangeEnd = -1

        # Parse out the Import Statements.
        self._parseImports()

        # Update the Buffer with the Sorted Import Statements.
        self._updateBuffer(self._sortImports())

    # Extract and Separate Imports.
    def _parseImports(self):
        self._separateImports(self._extractImports())

    def _sortImports(self):
        fullySortedImportStatements = list()

        # Sort Top Imports
        regexTopImports = self._topImports
        self._importTopImpList = self._regexSort(self._importTopImpList, regexTopImports)

        # Sort Middle Imports.
        self._importMiddleList = self._regexSort(self._importMiddleList, list())

        # Sort Bottom Imports.
        regexBottomImports = self._bottomImports
        self._importBottomList = self._regexSort(self._importBottomList, regexBottomImports)

        # Sort Static Imports.
        self._importStaticList = self._regexSort(self._importStaticList, list())

        # Add Static Imports first (if configured to do so)
        if self._staticFirst:
            fullySortedImportStatements.extend(self._importStaticList)

        # Add Top Imports
        fullySortedImportStatements.extend(self._importTopImpList)

        # Add Middle Imports
        fullySortedImportStatements.extend(self._importMiddleList)

        # Add Bottom Imports
        fullySortedImportStatements.extend(self._importBottomList)

        # Add Static Imports last (if configured to do so)
        if not self._staticFirst:
            fullySortedImportStatements.extend(self._importStaticList)

        #Create vertical indices for groups. +1 for spaces
        #self._topInd = len(self._importTopImpList)+1
        self._middleInd = self._topInd + len(self._importMiddleList)+1
        self._bottomInd = self._middleInd + len(self._importBottomList)+1

        return fullySortedImportStatements

    
    # Sort the provided importStatements first by the provided importRegexList, then
    # alphanumerically.
    def _regexSort(self, importStatements, importRegexList):
        regexSortedList = list()

        #put longer imports after shorter imports
        def sortLongestSecond(first, second):
            if second.startswith(first[:-1]):
                return -1
            if first.startswith(second[:-1]):
                return 1
            elif second < first:
                return 1
            elif first < second:
                return -1
            else:
                return 0

        # First sort the list alphanumerically.
        # Sort with custom comparator
        if self._sortLongerSecond:
            importStatements.sort(sortLongestSecond)
        else:
            importStatements.sort()

        # If the regex list is non-empty
        if len(importRegexList) > 0:
            # Precompile the regexes from the provided list of regex strings.
            compiledRegexList = list()
            for regexString in importRegexList:
                compiledRegexList.append(re.compile(self.IMPORT_BEGIN + regexString))

            # Bucketize the import statements by their matching regex.
            for compiledRegex in compiledRegexList:
                for importStatement in importStatements:
                    if compiledRegex.match(importStatement):
                        regexSortedList.append(importStatement)

        # If the regex list was empty, the sorted list is the answer.
        else:
            regexSortedList = importStatements

        return regexSortedList



    # Given a list of import statements, divide it into top, static and normal
    # imports.
    def _separateImports(self, importStatements):
        # Get list of Static Imports.
        regexStaticImports = ["static\s+"]
        self._importStaticList = self._extractImportsGivenRegexList(importStatements, regexStaticImports)

        # Get list of Bottom Imports.
        regexBottomImports = self._bottomImports
        self._importBottomList = self._extractImportsGivenRegexList(importStatements, regexBottomImports)

        # Get list of Top Imports.
        regexTopImports = self._topImports
        self._importTopImpList = self._extractImportsGivenRegexList(importStatements, regexTopImports)

        # Anything remaining is a Middle Import.
        self._importMiddleList = importStatements

    # Return a list of all import statements from the buffer.  Set globals which
    # denote the beginning and end of the range of import statements.
    def _extractImports(self):
        self._rangeStart = -1
        self._rangeEnd = -1
        
        importStatements = list()
        
        # Compile the Regex to Match Middle Import Statements.
        regexBeginningOfImportStatment = re.compile(self.IMPORT_BEGIN)

        # Find All Import Statements.
        lastMatch = -1
        for lineNum, line in enumerate(vim.current.buffer):
            if (regexBeginningOfImportStatment.match(line)):
                # Indicate the Start of the Import Statement Range if not yet set.
                if self._rangeStart == -1:
                    self._rangeStart = lineNum
        
                lastMatch = lineNum
                # Add the matching import to the list.
                importStatements.append(line)

        # Indicate the End of the Import Statement Range.
        self._rangeEnd = lastMatch
        
        return importStatements

    # Return a list of matching imports given a list of import statements and a
    # list of regular expression strings.
    def _extractImportsGivenRegexList(self, importStatements, importRegexList):
        matchingImportsList = list()

        # Precompile the regexes from the provided list of regex strings.
        compiledRegexList = list()
        for regexString in importRegexList:
            compiledRegexList.append(re.compile(self.IMPORT_BEGIN + regexString))

        # Iterate over the provided list of import statements.
        for importStatement in list(importStatements):

            # Iterate over each of the compiled regexes.
            for compiledRegex in compiledRegexList:

                # If the import statement matches the regex,
                if compiledRegex.match(importStatement):
                    # Add the matching import to the list.
                    matchingImportsList.append(importStatement)

                    # Remove the matching import from the provided list.
                    importStatements.remove(importStatement)

                    # The import statement matches, no need to continue checking
                    # against more regexes.
                    break

        return matchingImportsList

    # Determine if a separator is required between the two provided imports, given
    # a depth into the imports to check.  Depth is the number of package levels to
    # check (i.e. the number of dots in the import statement).
    def _isSeparatorRequired(self, prevImport, currImport, depth):
        prevList = prevImport.split(".", depth)
        currList = currImport.split(".", depth)

        del prevList[-1]
        del currList[-1]

        return prevList != currList

    # Insert spacing into a sorted list of packages.
    def _insertSpacing(self, importStatements, depth):
        # Copy the importStatements into a separate variable so that we are not iterating
        # over the list we are editing.
        spacedList = list(importStatements)

        # Review each entry of the list, if a separator is required, insert it.
        row = 0
        prevImport = ""
        currImport = ""
        for currImport in importStatements:
            if not prevImport:
                prevImport = currImport

            if self._isSeparatorRequired(prevImport, currImport, depth):
                spacedList.insert(row, "")
                row += 1

            if self._spacesAfterGroups:
                if row == 0:
                    spacedList.insert(row, "")
                    row += 1
            
                elif row == self._middleInd:
                    spacedList.insert(row, "")
                    row += 1

                #need to check if the bottom list is there. otherwise don't 
                #put a space
                elif row == self._bottomInd and len(self._importStaticList) != 0:
                    spacedList.insert(row, "")
                    row += 1

            prevImport = currImport
            row += 1

        # Remove Last Blank Entry (if present)
        if len(spacedList) and not spacedList[-1]:
            del spacedList[-1]

        return spacedList

    def _deleteRange(self, start, end):
        # Remove Existing Imports from the Buffer.
        del vim.current.buffer[start:end + 2]

    # Insert a list of lines into the buffer at the provided start line.
    def _insertListAtLine(self, startLine, lineList):
        # Do not append an empty list since this will insert an additional newline.
        if len(lineList):

            # Append the Sorted List to the Buffer.
            # If start line is before the beginning of the file, prepend the list
            # to the buffer.
            if startLine < 0:
                vim.current.buffer[0:0] = lineList
            # Otherwise, append the list below the provided startLine.
            else:
                # Append the Sorted List to the Buffer.
                vim.current.buffer.append(lineList, startLine)

        # Return Cursor Position After Inserted Lines.
        return startLine + len(lineList)

    # Update the Buffer with the fully sorted list of import statements, adding
    # empty lines as configured.
    def _updateBuffer(self, fullySortedImportStatements):
        # Remove the range of imports.
        self._deleteRange(self._rangeStart, self._rangeEnd)

        # Insert Spacing into Middle Import List.
        spacedList  = self._insertSpacing(fullySortedImportStatements, self._depth)

        startLine = self._rangeStart - 1

        startLine = self._insertListAtLine(startLine, spacedList)

        # Insert a newline at the end.
        if self._newLineAtEnd:
            startLine = self._insertListAtLine(startLine, [""])

sorter = Sorter()
