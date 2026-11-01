package com.sosuisha.main;

import javafx.application.Application;

/**
 * Entry point of the application.
 * This launcher class starts the JavaFX runtime from the classpath.
 */
public class Launcher {
    /**
     * Application entry point.
     *
     * @param args command line arguments
     */
    public static void main(String[] args) {
        // StageStyle.EXTENDED and HeaderBar are preview features of JavaFX 26.
        // The native exe has no JVM options, so the switch is set here, before
        // the JavaFX toolkit starts and reads it.
        System.setProperty("javafx.enablePreview", "true");
        Application.launch(App.class, args);
    }
}
