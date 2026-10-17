const handle = require('../server/meal_vote_handler').createHandler();
module.exports = (req, res) => handle('meals', req, res);
