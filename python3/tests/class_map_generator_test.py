import pathlib
import requests
import tarfile
import unittest
import zipfile
from class_map_generator import PortedClassMapGenerator

class PortedClassMapGeneratorTest(unittest.TestCase):

    def setUp(self):
        self.WORKSPACE_DIRECTORY = "./testWorkspace/"
        self.PATH_SEPARATOR = ","
        self.IMPORT_DIRECTORY = self.WORKSPACE_DIRECTORY + "imports/"
        self.DATA_DIRECTORY = self.WORKSPACE_DIRECTORY + "config/"
        self.JAR_CACHE = self.WORKSPACE_DIRECTORY + "cache/"

        pathlib.Path(self.WORKSPACE_DIRECTORY).mkdir()
        pathlib.Path(self.IMPORT_DIRECTORY).mkdir()
        pathlib.Path(self.DATA_DIRECTORY).mkdir()
        pathlib.Path(self.JAR_CACHE).mkdir()

    def tearDown(self):
        self.__cleanDir(pathlib.Path(self.WORKSPACE_DIRECTORY))
        self.JAR_CACHE = ""
        self.DATA_DIRECTORY = ""
        self.IMPORT_DIRECTORY = ""
        self.PATH_SEPARATOR = ""
        self.WORKSPACE_DIRECTORY = ""

    def __cleanDir(self, workspaceDirectory):
        for workspaceItem in pathlib.Path(workspaceDirectory).iterdir():
            if workspaceItem.is_file():
                workspaceItem.unlink()
            elif workspaceItem.is_dir():
                self.__cleanDir(workspaceItem)

        workspaceDirectory.rmdir()

    def test_import_java_sources(self):
        # Generate class map for Guava v20 (from source files)
        self.__addGuavaToWorkspaceSource()
        importPaths = self.PATH_SEPARATOR.join([
            self.IMPORT_DIRECTORY + "guava-20.0/guava-testlib/src",
            self.IMPORT_DIRECTORY + "guava-20.0/guava/src",
            self.IMPORT_DIRECTORY + "guava-20.0/guava-gwt/src"
        ])
        PortedClassMapGenerator(self.PATH_SEPARATOR, importPaths, self.DATA_DIRECTORY, self.JAR_CACHE)

        self.assertTrue(self.__importFileExists())
        self.assertEqual(self.__importFileCountLines(), 845)
        self.assertTrue(self.__importFileIsSorted())

    def test_import_java_classes(self):
        # Generate class map for Guava v20 (from class files)
        self.__addGuavaToWorkspaceClasses()
        importPaths = self.PATH_SEPARATOR.join([
            self.IMPORT_DIRECTORY + "classes"
        ])
        PortedClassMapGenerator(self.PATH_SEPARATOR, importPaths, self.DATA_DIRECTORY, self.JAR_CACHE)

        self.assertTrue(self.__importFileExists())
        self.assertEqual(self.__importFileCountLines(), 2502)
        self.assertTrue(self.__importFileIsSorted())

    def test_import_jar(self):
        # Generate class map for Guava v20 (from jar files)
        self.__addGuavaToWorkspaceJars()
        importPaths = self.PATH_SEPARATOR.join([
            self.IMPORT_DIRECTORY
        ])
        PortedClassMapGenerator(self.PATH_SEPARATOR, importPaths, self.DATA_DIRECTORY, self.JAR_CACHE)

        self.assertTrue(self.__importFileExists())
        self.assertEqual(self.__importFileCountLines(), 2502)
        self.assertTrue(self.__importFileIsSorted())

    def test_import_java_jmplst(self):
        # Generate class map for Guava v20 (from jmplst files)
        self.__addGuavaToWorkspaceJmplst()
        importPaths = self.IMPORT_DIRECTORY
        PortedClassMapGenerator(self.PATH_SEPARATOR, importPaths, self.DATA_DIRECTORY, self.JAR_CACHE)

        self.assertTrue(self.__importFileExists())
        self.assertEqual(self.__importFileCountLines(), 2502)
        self.assertTrue(self.__importFileIsSorted())

    def __addGuavaToWorkspaceSource(self):
        # Download and extract source code for Guava v20
        localFilename = self.WORKSPACE_DIRECTORY + 'v20.0.tar.gz'
        remoteFilename = 'https://github.com/google/guava/archive/v20.0.tar.gz'
        self.__downloadFile(localFilename, remoteFilename)
        javaLibraryTar = tarfile.open(localFilename)
        javaLibraryTar.extractall(self.IMPORT_DIRECTORY)

    def __addGuavaToWorkspaceJars(self):
        remoteFolder = 'https://github.com/google/guava/releases/download/v20.0/'
        for fileName in ['guava-20.0.jar', 'guava-gwt-20.0.jar', 'guava-testlib-20.0.jar']:
            self.__downloadFile(self.IMPORT_DIRECTORY + fileName, remoteFolder + fileName)

    def __addGuavaToWorkspaceClasses(self):
        remoteFolder = 'https://github.com/google/guava/releases/download/v20.0/'
        for fileName in ['guava-20.0.jar', 'guava-gwt-20.0.jar', 'guava-testlib-20.0.jar']:
            self.__downloadJarAndExtract(self.WORKSPACE_DIRECTORY + fileName, remoteFolder + fileName)

    def __addGuavaToWorkspaceJmplst(self):
        remoteFolder = 'https://github.com/google/guava/releases/download/v20.0/'
        for fileName in ['guava-20.0.jar', 'guava-gwt-20.0.jar', 'guava-testlib-20.0.jar']:
            self.__downloadJarAsJmplst(self.IMPORT_DIRECTORY + fileName, remoteFolder + fileName)

    def __downloadJarAsJmplst(self, localFilename, remoteFilename):
        self.__downloadFile(localFilename, remoteFilename)
        with zipfile.ZipFile(localFilename) as jarFile:
            with open(localFilename + ".jmplst", mode = 'w') as jmplst:
                for line in jarFile.namelist():
                    print(line, file = jmplst);

        pathlib.Path(localFilename).unlink()

    def __downloadJarAndExtract(self, localFilename, remoteFilename):
        self.__downloadFile(localFilename, remoteFilename)
        with zipfile.ZipFile(localFilename) as jarFile:
            jarFile.extractall(self.IMPORT_DIRECTORY + "classes")

    def __downloadFile(self, localFilename, remoteFilename):
        with requests.get(remoteFilename) as r:
            r.raise_for_status()
            with open(localFilename, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)

    def __importFileBuildFile(self):
        return pathlib.Path(self.DATA_DIRECTORY) / "JavaImp.txt"

    def __importFileExists(self):
        return self.__importFileBuildFile().exists()

    def __importFileGetLines(self):
        javaImpTxtFile = self.__importFileBuildFile()
        javaImpTxtFileContents = javaImpTxtFile.read_text()
        return javaImpTxtFileContents.split("\n")

    def __importFileCountLines(self):
        return len(self.__importFileGetLines())

    def __importFileIsSorted(self):
        javaImpTxtFileLines = self.__importFileGetLines()
        javaImpTxtFileSortedLines = sorted(javaImpTxtFileLines)
        linesInSameOrder = True
        for i in (len(javaImpTxtFileLines) - 1, 0):
            if javaImpTxtFileLines[i] != javaImpTxtFileSortedLines[i]:
                linesInSameOrder = False
                break
        return linesInSameOrder
