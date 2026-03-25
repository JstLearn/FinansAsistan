const mongoose = require('mongoose');
const YetkiSchema = new mongoose.Schema({ ad: String });
module.exports = mongoose.model('Yetki', YetkiSchema);
