// Jenkinsfile
// Weekly build of all supported devices for the frosty-aosp ROM.
// Job type: Pipeline script from SCM, pointed at the repo containing this
// file, devices.txt, and scripts/.
//
// Requires plugins: Credentials Binding, AWS Credentials, Timestamper.

pipeline {
    agent { label 'aosp-builder' }

    options {
        timestamps()
        timeout(time: 30, unit: 'HOURS')
        disableConcurrentBuilds()
    }

    triggers {
        // Once a week, Sunday ~02:xx (H spreads the exact minute).
        cron('H 2 * * 0')
    }

    parameters {
        string(name: 'MANIFEST_URL', defaultValue: 'https://github.com/frosty-aosp/manifest.git',
               description: 'ROM manifest repo')
        string(name: 'MANIFEST_BRANCH', defaultValue: 'ananas',
               description: 'Manifest branch/revision to build')
        string(name: 'DEVICES_FILTER', defaultValue: '',
               description: 'Comma-separated codenames to build. Empty = build every device in devices.txt')
    }

    environment {
        SRC_DIR      = '/code/frosty'   // persistent shared source tree, survives across runs
        CCACHE_DIR   = '/code/ccache'
        USE_CCACHE   = '1'
        CCACHE_SIZE  = '200G'
        S3_BUCKET    = 's3://frosty-builds'
        DEVICES_FILE = "${WORKSPACE}/devices.txt"
    }

    stages {
        stage('Checkout CI config') {
            steps {
                checkout scm
            }
        }

        stage('Sync base source') {
            steps {
                sh '''
                    set -e
                    mkdir -p "$SRC_DIR" "$CCACHE_DIR"
                    cd "$SRC_DIR"
                    if [ ! -d .repo ]; then
                        repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH"
                    fi
                    repo sync -c -j4 --force-sync --no-clone-bundle --no-tags
                '''
            }
        }

        stage('Build devices') {
            steps {
                script {
                    def allDevices = readFile(env.DEVICES_FILE)
                        .readLines()
                        .collect { it.trim() }
                        .findAll { it && !it.startsWith('#') }

                    def filterRaw = params.DEVICES_FILTER?.trim()
                    def wanted = filterRaw ? filterRaw.split(',').collect { it.trim() } : null
                    def failed = []

                    for (codename in allDevices) {
                        if (wanted && !wanted.contains(codename)) {
                            continue
                        }

                        stage("Build: ${codename}") {
                            try {
                                // breakfast triggers roomservice, which fetches this
                                // device's tree (and its kernel/vendor deps) from
                                // frosty-devices, syncs just the new projects, and
                                // resolves the right lunch combo — no prefix needed.
                                sh """
                                    set -e
                                    cd "\$SRC_DIR"
                                    source build/envsetup.sh
                                    breakfast ${codename}
                                    mka installclean
                                    mka bacon
                                """

                                withCredentials([[
                                    $class: 'AmazonWebServicesCredentialsBinding',
                                    credentialsId: 'frosty-s3-uploader'
                                ]]) {
                                    sh """
                                        bash "\$WORKSPACE/scripts/upload_artifacts.sh" \
                                            "\$SRC_DIR/out/target/product/${codename}" \
                                            "${codename}"
                                    """
                                }
                            } catch (err) {
                                echo "Build failed for ${codename}: ${err}"
                                failed.add(codename)
                            }
                        }
                    }

                    if (failed) {
                        currentBuild.result = 'UNSTABLE'
                        echo "Devices that failed this run: ${failed.join(', ')}"
                    }
                }
            }
        }
    }

    post {
        always {
            sh 'df -h "$SRC_DIR" || true'
        }
        unstable {
            echo 'One or more devices failed to build — check the per-device stage logs above.'
        }
    }
}
