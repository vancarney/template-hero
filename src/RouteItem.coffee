fs = require 'fs-extra'
path = require 'path'
{_} = require 'lodash'
class RouteItem
  constructor:(@route_item)->
  save:(callback)->
    throw 'callback required' unless callback? and typeof callback is 'function'
    fs.ensureDir path.dirname( p = @route_item.route_file ), (e)=>
      return callback.apply @, arguments if e?
      fs.writeFile "#{p}.js", @template(@route_item), {flag:'wx+'}, (e)=>
        callback.apply @, arguments if e?
        fs.writeFile "#{p}.json", JSON.stringify(@route_item, null, 2), {flag:'wx+'}, (e)=>
          callback.apply @, arguments

RouteItem::template = _.template """
/**
 * <%= name %>.js
 * Route Handler File
 * Generated by Jade-Router for ApiHero 
 */
var _ = require('lodash');
var _app_ref;
var config = require('./<%= name %>.json');
var render = function(res, model) {
  res.render( config.template_file, JSON.parse(JSON.stringify(model)), function(e,html) {
    if (e !== null) console.log(e);
    res.send(html);
  }); 
};

var <%= name %>Handler = function(req, res, next) {
  // attempts to determine name for `Query Method` defaults to 'find'
  var funcName = config.queryMethod || 'find';

  // attempts to determine `Collection Name` defaults to config name for route
  var collectionName = (( name = config.collectionName) == "") ? null : name;

  // placeholds the result object
  var model = {
    meta : []
  };

  // tests for Collection Name
  if (collectionName == null && _app_ref.models.hasOwnProperty(collectionName) == false)
    // renders page and returns if no Collection Name was defined
    return render(res, model);

  // performs Query Execution
  var execQuery = function(colName, funName, q, cB) {

    // tests for existance of query arguments defintion
    if (q.hasOwnProperty('arguments')) {
      // captures values of argument properties
      var args = _.values(q.arguments);
      // pushes callback into argument values array
      args.push(cB);

      // applies arguments array with callback upon Collection Operation
      return _app_ref.models[colName][funName].apply(this, args);
    }

    // invokes Collection Operation with Query and Callback only
    return _app_ref.models[colName][funName](q, cB);
  };


  // processes query from Configuration and Request Query and Params Object
  var processQuery = function(c_query, callback) {

    // holds `name` of Response Object Element
    var elName = c_query.hasOwnProperty('name') ? c_query.name : 'results';

    // holds `name` of Collection to perform Operations against
    var colName = c_query.hasOwnProperty('collectionName') ? c_query.collectionName : collectionName;

    // holds `name` of Operation to perform against Collection
    var funName = c_query.hasOwnProperty('queryMethod') ? c_query.queryMethod : (funcName || 'find');

    // checks for Required Arguments property set on Query config
    if (c_query.query.hasOwnProperty('required') && _.isArray(c_query.query.required)) {
      // holds missing arguments that were required
      var missing;
      // checks for existance of all required arguments
      if (( missing = _.difference(c_query.query.required, _.keys(req.query))).length > 0)
        // returns user error if missing a required argument
        return res.status(400).send("required argument '" + missing[0] + "' was missing from query params");
    }

    // tests for arguments element on Query Settings Object
    if (c_query.query.hasOwnProperty('arguments')) {

      // loops on each arguments defined
      for (arg in c_query.query.arguments) {

        // skips unprocessable arguments
        if (!c_query.query.arguments[arg])
          continue;

        // tests for argument values that match `:` or `?`
        if (( param = c_query.query.arguments[arg].match(/^(\\:|\\?)+([a-zA-Z0-9-_]{1,})+$/)) != null) {
          // if value matched `:`, that is a ROUTE PARAMETER such as /:id and is applied against request.params
          // if value matched `?`, that is a REQUEST QUERY PARAMETER such as ?param=value and is applied against request.query
          c_query.query.arguments[arg] = req[(param[1] === ':' ? 'params' : 'query')]['' + param[2]];
        }
      }
    }

    // wraps passed calllback for negotiation
    var cB = function(e, res) {
      if (e != null) {
        // invokes callback and returns in case of error
        return callback(e);
      }

      // placeholds results object
      var o = {};

      // applies defined Result Element Name withj results
      o[elName] = res;

      // passes formatted results to callback
      callback(null, o);
    };

    // invokes Query Execution Method with Collection, Operation Method and Query
    execQuery(colName, funName, c_query.query, cB);
  };

  // tests if configured Query element is an `Array`
  if (_.isArray(config.query)) {
    // defines completion method
    var done = _.after(config.query.length, function(e, resultset) {
      if (e != null) {
        console.log(e);
        return res.sendStatus(500);
      }
      // invokes render with result set
      render(res, resultset);
    });

    // loops on each configured query passed
    _.each(config.query, function(q) {
      // inokes Query Processing method
      processQuery(_.cloneDeep(q), function(e, res) {
        // invokes done each iteration
        done(e, _.extend(model, res));
      });
    });
  } else {

    // is a single query configuration -- process directly
    processQuery(_.cloneDeep(config.query), function(e, resultset) {
      if (e != null) {
        console.log(e);
        return res.sendStatus(500);
      }

      // invokes render with result set
      render(res, _.extend(model, resultset));
    });
  }

};

// Routeing Module Entry Point
module.exports.init = function(app) {
  // holds reference to Application
  _app_ref = app;
  // tests for RegExp based route as denoted by a `rx:` prefix
  var route = (s = config.route.split('rx:')).length > 1 ? new RegExp(s.pop()) : config.route;
  // applies the Route and Handler Method to a GET Request 
  app.get(route, <%= name %>Handler);
};
"""
module.exports = RouteItem