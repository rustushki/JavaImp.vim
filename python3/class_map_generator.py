import pathlib
import re
import subprocess

class PortedClassMapGenerator:
    def __init__(self, pathSeparator, importPaths, dataDir, jarCache):
        self._pathSeparator = pathSeparator
        self._importPaths = importPaths
        self._dataDir = dataDir
        self._jarCache = jarCache

        formattedClassEntrySet = self._buildFileSet()

        formattedLineList = sorted(formattedClassEntrySet)

        with open(self._dataDir + "/JavaImp.txt", "w") as outfile:
            outfile.write("\n".join(formattedLineList))

    def _formatClassEntry(self, pathToJavaClassString):
        formattedClassEntry = ""
        match = re.search("[\\\/]([\$\w_]+)$", pathToJavaClassString)
        if match:
            # Remove Preceding Slash (if present)
            qualifiedClassName = re.sub("^[\\\/]", "", pathToJavaClassString)

            # Slashes and Dollars to Dots
            qualifiedClassName = re.sub("[\\\/]|\$", ".", qualifiedClassName)

            className = re.sub("\$", ".", match.group(1))
            formattedClassEntry = className + ' ' + qualifiedClassName

        return formattedClassEntry

    def _buildFileSet(self):
        importPathStringList = self._importPaths.split(self._pathSeparator)

        formattedClassEntrySet = set()

        for packageRootString in importPathStringList:
            print("Searching in path (package): " + packageRootString)
            packageRootPath = pathlib.Path(packageRootString)
            self._addFilesInPath(formattedClassEntrySet, packageRootPath, packageRootPath)

        return formattedClassEntrySet

    def _addFilesInPath(self, formattedClassEntrySet, packageRootPath, path):
        if path.is_dir():
            self._addPathStringsFromDirectory(formattedClassEntrySet, packageRootPath, path)

        elif path.is_file():
            extension = path.suffix.lower()
            if extension == '.jar':
                self._addPathStringsFromJar(formattedClassEntrySet, path)
            elif extension == '.jmplst':
                self._addPathStringsFromJmpList(formattedClassEntrySet, path)
            else:
                self._addPathStringFromFile(formattedClassEntrySet, packageRootPath, path)

    def _addPathStringsFromDirectory(self, formattedClassEntrySet, packageRootPath, path):
        for child in path.iterdir():
            self._addFilesInPath(formattedClassEntrySet, packageRootPath, child)

    def _addPathStringFromFile(self, formattedClassEntrySet, packageRootPath, path):
        self._addPathStringIfJavaClass(formattedClassEntrySet, str(packageRootPath), str(path))

    def _addPathStringsFromJar(self, formattedClassEntrySet, jarPath):
        cachedJarPath = self._findCachedJar(jarPath)

        if not cachedJarPath.exists() or cachedJarPath.stat().st_mtime < jarPath.stat().st_mtime:
            print(" - Updating jar: " + jarPath.name)

            completedProcess = subprocess.run(["jar", "tf", str(jarPath)], capture_output=True, text=True)

            if completedProcess.returncode != 0:
                print("  - Error running the jar command: " + " ".join(completedProcess.args))
            else:
                cachedJarPath.write_text(completedProcess.stdout)
                self._addPathStringsFromJmpList(formattedClassEntrySet, cachedJarPath)

            print(" ")

    def _addPathStringsFromJmpList(self, formattedClassEntrySet, path):
        with open(path, "r") as infile:
            for filePathString in infile.readlines():
                self._addPathStringIfJavaClass(formattedClassEntrySet, "", filePathString)

    def _addPathStringIfJavaClass(self, formattedClassEntrySet, packageRootPath, filePathString):
        filePathString = filePathString.strip()
        if filePathString.lower().endswith((".java", ".class")):
            filePathStringSansExtension = re.sub("\.class|\.java", "", filePathString)
            filePathStringSansParentDirectories = filePathStringSansExtension.replace(packageRootPath, "")
            formattedClassEntrySet.add(self._formatClassEntry(filePathStringSansParentDirectories))

    def _findCachedJar(self, jarToCheckPath):
        cachedJarFileName = str(jarToCheckPath)
        cachedJarFileName = re.sub('[ :\\\/]', '_', cachedJarFileName)
        cachedJarFileName = re.sub('jar$', 'jmplst', cachedJarFileName)
        return pathlib.Path(self._jarCache) / cachedJarFileName
