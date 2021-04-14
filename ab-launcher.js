/**
 * 1. Updates the config files to use the actual runtime DB credentials
 * 2. Tests the DB connection
 * 3. Lifts sails
 *
 * At runtime the MySQL root password is expected to be found in a plaintext 
 * config file located at "/secret/password"
 */

const fs = require('fs');
const async = require('async');
const mysql = require('mysql');

// Standard AppBuilder DB settings
const host = 'db'; // refers to the mariadb service in the docker stack
const port = '3306';
const db = 'site';
const user = 'root';
var password = 'root'; // will be updated below

/**
 * Step 1: Update runtime DB credentials
 */
// Warn if password file was not mounted
if (!fs.existsSync('/secret/password')) {
    console.warn('Warning: DB password /secret/password file not found.');
}
else {
    // Mounted runtime password
    password = fs.readFileSync('/secret/password', 'utf8').trim();

    // Read config files
    var adn = require('/app/.adn');
    var localJS = require('/app/config/local.js');

    // Update DB credentials
    adn.defaults['label-host'] = host;
    adn.defaults['label-port'] = port;
    adn.defaults['label-user'] = user;
    adn.defaults['label-pass'] = password;
    adn.defaults['label-db'] = db;
    localJS.connections.appdev_default.host = host;
    localJS.connections.appdev_default.port = port;
    localJS.connections.appdev_default.user = user;
    localJS.connections.appdev_default.password = password;
    localJS.connections.appdev_default.database = db;
    //localJS.appbuilder.mcc.enabled = false;

    // Write config files
    fs.writeFileSync(
        '/app/.adn', 
        "module.exports = " + JSON.stringify(adn, null, 4)
    );
    fs.writeFileSync(
        '/app/config/local.js', 
        "module.exports = " + JSON.stringify(localJS, null, 4)
    );
}


/**
 * Step 2: Test DB connection
 */
var connection;
var isConnectedDB = false;
var dbConnectCount = 0;
async.doUntil(
    // do iterations
    (next) => {
        connection = mysql.createConnection({
            host: host,
            user: user,
            password: password,
            database: db
        });
        dbConnectCount += 1;
        console.log('Testing DB connection...');
        connection.connect((err) => {
            if (err) {
                console.warn(err.message || err);
                setTimeout(() => {
                    next();
                }, 500);
            }
            else {
                isConnectedDB = true;
                next();
            }
        })
    },
    // terminating condition
    (until) => {
        connection.destroy();
        if (isConnectedDB) {
            until(null, true);
        }
        else if (dbConnectCount >= 100) {
            console.error('Unable to connect to DB after 100 attempts')
            until(null, true);
        }
        else {
            console.warn('Retrying...');
            until(null, false);
        }
    },
    // final
    (err) => {
        if (isConnectedDB) {
            console.log('OK!');

            /**
             * Step 3: Lift Sails 
             */
            console.log('Lifting Sails');
            require(__dirname + '/app.js');
        }
        else {
            process.exit();
        }
    }
);
