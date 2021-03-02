/**
 * This file originates from /tmp/app.tar.tbz of the AppBuilder 
 * developer image.
 * @see https://hub.docker.com/layers/skipdaddy/install-ab/developer_v2/images/sha256-bcb61157b831c042dc6beaa08ef4453c52bfc6800183f6f004d82048d203d1dd
 */

//
// Re Setup all modules in our project
//
// clear the stealconfig.js to original (empty) state, then 
// rerun all the setup/setup.js scripts to rebuild the stealconfig.js
// to proper values.
//
// This is necessary after some code updates that have changes to the 
// build configurations.

var path = require('path');
var fs = require('fs');
var async = require('async');
var AD = require('ad-utils');
var _ = require('lodash');

var pathNodeModules = path.join('node_modules');



function runSetup(pathDirectory, cb) {
	var pathSetup = path.join(pathDirectory, 'setup', 'setup.js');
	if(fs.existsSync(pathSetup)) {
		var cwd = process.cwd();
		process.chdir(pathDirectory);
		console.log('... '+ pathDirectory);

		async.series([

// 			(next)=>{
// 				AD.spawn.command({
// 					command:'npm',
// 					options:['install'],
// shouldEcho:true
// 					// shouldEcho:false
// 				})
// 				.fail(function(err){
// 					next(err);
// 				})
// 				.then(function(code){
// 					next();
// 				});
// 			},

			(next)=>{
				AD.spawn.command({
					command:'node',
					options:[path.join('setup', 'setup.js')],
shouldEcho:true
					// shouldEcho:false
				})
				.fail(function(err){
					next(err);
				})
				.then(function(code){
					next();
				});
			}

		], (err,data)=>{
			process.chdir(cwd);
			cb(err);
		})
	    

	} else {
		cb();
	}
}


function processDirectory(list,cb) {
	if (list.length == 0) {
		cb();
	} else {

		var entry = list.shift();
		var directory = path.join(pathNodeModules, entry);

		runSetup(directory, function(err){
			 if (err) {
			 	cb(er);
			 } else {
			 	processDirectory(list, cb);
			 }
		})
	}
}


function findAllDirectories(cb) {
	fs.readdir(pathNodeModules, function(err, entries){

		processDirectory(entries, cb);

	})
}



function saveStealConfig (cb) {
	var pathStealConfig = path.join('assets', 'stealconfig.js');


	// Backup Current stealconfig.js
	var num = 0;
	var backupFile = pathStealConfig + '.bak'+num;

	while(fs.existsSync(backupFile)) {
		num++;
		backupFile = pathStealConfig + '.bak'+num;
	}

	var contents = fs.readFileSync(pathStealConfig, 'utf8');
	fs.writeFileSync(backupFile, contents, 'utf8');


	// create a clean stealconfig.js
	var contents = [
'steal.config({',
'    "map": {},',
'    "paths": {},',
'    "bundle": [],',
'    "meta": {},',
'    "ext": {},',
'    "buildConfig": {}',
'});'
	].join('\n');


	fs.writeFileSync(pathStealConfig, contents, 'utf8');


	// continue on with each of our module directories:
	findAllDirectories(cb);
}


// kick things off:
// if called directly like:  $ node reSetup.js
if (require.main === module) {
	// just start the process:
    saveStealConfig((err)=>{
		if (err) {
			console.error(err);
		}
		console.log(' ... finished.');
	})

} else {
	// we are included using: require("reSetup.js")
	// so return our .run() api:
	module.exports = {
	    run:saveStealConfig
	}
}
