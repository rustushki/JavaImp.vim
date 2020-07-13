import unittest
import pathlib
import requests
import tarfile
import subprocess
import sys
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
        self.__addGuavaToWorkspace()

        # Generate class map for Guava v20
        importPaths = self.PATH_SEPARATOR.join([
            self.IMPORT_DIRECTORY + "guava-20.0/guava-testlib/src",
            self.IMPORT_DIRECTORY + "guava-20.0/guava/src",
            self.IMPORT_DIRECTORY + "guava-20.0/guava-gwt/src"
        ])
        class_map_generator = PortedClassMapGenerator(self.PATH_SEPARATOR, importPaths, self.DATA_DIRECTORY,
                self.JAR_CACHE)

        # Verify that JavaImp.txt is created
        javaImpTxtFile = pathlib.Path(self.DATA_DIRECTORY) / "JavaImp.txt"
        self.assertTrue(javaImpTxtFile.exists())

        # Verify the count of importable classes in the library
        javaImpTxtFileContents = javaImpTxtFile.read_text()
        javaImpTxtFileLines = javaImpTxtFileContents.split("\n")
        self.assertEqual(len(javaImpTxtFileLines), 845)

        # Verify that the lines in JavaImp.txt are sorted
        javaImpTxtFileSortedLines = sorted(javaImpTxtFileLines)
        linesInSameOrder = True
        for i in (0, len(javaImpTxtFileLines) - 1):
            if javaImpTxtFileLines[i] != javaImpTxtFileSortedLines[i]:
                linesInSameOrder = False
                break
        self.assertTrue(linesInSameOrder)

    def test_import_java_classes(self):
        self.__addGuavaToWorkspace()
        self.__buildMavenPackage(self.IMPORT_DIRECTORY + "guava-20.0/guava-testlib")
        self.__buildMavenPackage(self.IMPORT_DIRECTORY + "guava-20.0/guava")
        self.__buildMavenPackage(self.IMPORT_DIRECTORY + "guava-20.0/guava-gwt")


        # Generate class map for Guava v20
        importPaths = self.PATH_SEPARATOR.join([
            self.IMPORT_DIRECTORY + "guava-20.0/guava-testlib/target/classes",
            self.IMPORT_DIRECTORY + "guava-20.0/guava/target/classes",
            self.IMPORT_DIRECTORY + "guava-20.0/guava-gwt/target/classes"
        ])
        class_map_generator = PortedClassMapGenerator(self.PATH_SEPARATOR, importPaths, self.DATA_DIRECTORY,
                self.JAR_CACHE)

        # Verify that JavaImp.txt is created
        javaImpTxtFile = pathlib.Path(self.DATA_DIRECTORY) / "JavaImp.txt"
        self.assertTrue(javaImpTxtFile.exists())

        # Verify the count of importable classes in the library
        javaImpTxtFileContents = javaImpTxtFile.read_text()
        javaImpTxtFileLines = javaImpTxtFileContents.split("\n")
        self.assertEqual(len(javaImpTxtFileLines), 2503)

        # Verify that the lines in JavaImp.txt are sorted
        javaImpTxtFileSortedLines = sorted(javaImpTxtFileLines)
        linesInSameOrder = True
        for i in (0, len(javaImpTxtFileLines) - 1):
            if javaImpTxtFileLines[i] != javaImpTxtFileSortedLines[i]:
                linesInSameOrder = False
                break
        self.assertTrue(linesInSameOrder)

    def __buildMavenPackage(self, directory):
        completedProcess = subprocess.run(["mvn", "-Dmaven.test.skip=true", "clean", "package"], cwd=directory)

        if completedProcess.returncode != 0:
            print("Error running the mvn command: " + " ".join(completedProcess.args))
            sys.exit()
            

    def __addGuavaToWorkspace(self):
        # Download and extract source code for Guava v20
        localFilename = self.WORKSPACE_DIRECTORY + 'v20.0.tar.gz'
        remoteFilename = 'https://github.com/google/guava/archive/v20.0.tar.gz' 
        self.__downloadFile(localFilename, remoteFilename)
        javaLibraryTar = tarfile.open(localFilename)
        javaLibraryTar.extractall(self.IMPORT_DIRECTORY)

    def __downloadFile(self, localFilename, remoteFilename):
        with requests.get(remoteFilename) as r:
            r.raise_for_status()
            with open(localFilename, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192): 
                    f.write(chunk)
