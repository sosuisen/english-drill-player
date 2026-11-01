# English Drill Player

This is a practice audio player for "Eigo no Hanon" (English Hanon).

You need to buy "Eigo no Hanon" and download the audio files that come with it.

This player detects silence in the audio and automatically splits the audio into drills.

![screen](./images/screen.png)

## Install

1. Download `english-drill-player-<version>.zip` from [GitHub Releases](https://github.com/sosuisen/english-drill-player/releases).
2. Unzip it anywhere. It holds `english-drill-player.exe` and some `dll` files.
3. Run `english-drill-player.exe`.

The exe uses the `dll` files in the same folder. It does not run alone.

The exe is a GraalVM native image. You do not need to install a JDK.
Only Windows is supported.

## Requirements for Development

- Java 25
- Maven

To build the native exe, you also need:

- GraalVM CE 25.4
- The C++ build tools of Visual Studio

## How to Run

```bash
mvn javafx:run
```

## Development

### JavaFX Preview Features

The main window uses `StageStyle.EXTENDED` and `HeaderBar`, which are preview
features of JavaFX 26. These features require the system property
`javafx.enablePreview=true`. `Launcher` sets it before the JavaFX toolkit
starts, so `mvn javafx:run` and the native exe need no JVM option. The tests
do not go through `Launcher`, so `pom.xml` sets it for `mvn test`.

### How to Test

```bash
mvn test
```

The tests run in headless mode, so no window is opened.

### Survey of the Real Drill Files

`DrillBookSurveyTest` runs the segment detector and the drill book parser
over every MP3 file in a folder. It runs only when you specify the folder:

```bash
mvn test -Dtest=DrillBookSurveyTest "-Dedp.survey.folder=<path to the folder of the drill files>"
```

The test fails when a file cannot be split into drills. It then prints the sound and
silence lengths of that file. Run it after changing the detection
parameters or the parsing rules (see ADR 003 and ADR 004).

### How to Format

```bash
mvn formatter:format
```

## How to Build the Native Exe

The exe is built with GraalVM native image, so it starts without a JVM.
Set `JAVA_HOME` to GraalVM CE 25.4 and build with the `native` profile.

```bash
JAVA_HOME=<GraalVM CE 25.4 folder> mvn -Pnative package
```

- The output is under `target/`.
- The exe is `target/english-drill-player.exe`.
- To use it, copy the exe and the `dll` files next to it together. The exe does not run alone.

`mvn clean` deletes `target/`, so copy the files before you clean.

`mvn package` without the `native` profile does not build the exe.

The static JavaFX libraries come from [StaticFX](https://github.com/HebiRobotics/jfx-static-feature)
(`us.hebi.graalvm:jfx-static-libs`). Their version must match the JavaFX
version exactly. When you upgrade JavaFX, upgrade `jfx.static.libs.version`
in `pom.xml` with it.

### Metadata

Native image must know at build time which classes are used by reflection,
which resources are read, and which native methods are called. That
information is in `src/main/resources/META-INF/native-image/com.sosuisha/english-drill-player/reachability-metadata.json`.

A missing entry does not break the build or the tests. It breaks the exe at
run time. So rebuild the file when:

- A new resource is read, such as a CSS file or an image.
- A new JavaFX control is used.
- JavaFX, AtlantaFX, Ikonli, jOOQ, sqlite-jdbc, or javasound-mp3 is upgraded.
- A new start route or error route is added.

To rebuild it, run the app on the GraalVM JVM with the tracing agent. The
agent writes what it sees into the output folder.

1. Compile with `mvn compile`.
2. Build the runtime class path. Remove the test jars (junit, testfx, hamcrest,
   assertj, opentest4j, apiguardian, osgi) and the `us.hebi` jars from it, and
   put `target/classes` first.

   ```bash
   mvn -q -B -Pnative dependency:build-classpath -Dmdep.includeScope=runtime -Dmdep.outputFile=<temp file>
   ```

3. Run every route of the app with the agent. Use `config-merge-dir` so that
   all runs land in one folder.

   ```bash
   <GraalVM>/bin/java -agentlib:native-image-agent=config-merge-dir=<output folder> -Dedp.drill.db=<temp db> -cp "<class path>" com.sosuisha.main.Launcher
   ```

   - Start with an empty database, so that the folder dialog opens first.
     Register a folder, select a unit, play, pause, resume and stop, click a
     drill, move to the previous and the next drill, double-click a unit, and
     open the folder dialog again.
   - Start with `-Dedp.drill.db` pointing to a folder, so that the error dialog opens.

4. Run the test suite with the agent too. It covers routes that are hard to
   reach by hand. The test JVMs run in parallel, so each gets its own output folder.

   ```bash
   JAVA_HOME=<GraalVM> mvn test "-Dtest.jvm.options=-agentlib:native-image-agent=config-output-dir=<output folder>-{pid},config-write-period-secs=5,config-write-initial-delay-secs=5,access-filter-file=<filter>,caller-filter-file=<filter>"
   ```

   The filter excludes the test frameworks (`org.junit.**`, `org.testfx.**`,
   `org.hamcrest.**`, `org.opentest4j.**`, `org.apiguardian.**`,
   `org.assertj.**`, `org.apache.maven.**`, `com.uber.nullaway.**`).

5. Merge all output folders into the metadata file, and remove the entries for
   test classes (`com.sosuisha.**Test*`, `Null*` test doubles).

   ```bash
   <GraalVM>/bin/native-image-configure generate --input-dir=<folder 1> --input-dir=<folder 2> ... --output-dir=src/main/resources/META-INF/native-image/com.sosuisha/english-drill-player
   ```

### Icon

The exe icon is `images/icon.ico`. `src/windows/english-drill-player.rc`
names it, and the compiled `src/windows/english-drill-player.res` is passed
to the linker.

The `.res` file is committed, because `rc.exe` is not on the PATH of a normal
shell or of CI. When the icon changes, rebuild it with `rc.exe` from the
Windows SDK.

```powershell
cd src\windows
& "C:\Program Files (x86)\Windows Kits\10\bin\<version>\x64\rc.exe" /fo english-drill-player.res english-drill-player.rc
```

## Continuous Integration

GitHub Actions runs `.github/workflows/ci.yml` for every push to `main` and
every pull request. It checks the formatting and runs the tests on Windows.
For a push to `main`, it also builds the native exe, starts it once to check
that it opens a window, and uploads the exe and the `dll` files as a build
artifact. Documentation-only changes do not start it.

## Release

The app version comes from the Git tag only. Do not change the version in `pom.xml`.

To release, create a tag that starts with `v` and push it.

```bash
git tag v1.2.0
git push origin v1.2.0
```

The push starts the `release.yml` workflow of GitHub Actions.

1. It takes `1.2.0` from the tag name.
2. It runs the tests and builds the native exe.
3. It starts the exe once, waits for the window, and closes it.
4. It zips the exe and the `dll` files.
5. It creates a GitHub Release with `english-drill-player-1.2.0.zip` attached.

The version appears only in the zip name and the release title. The exe has
no version inside.
