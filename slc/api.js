// SERVICE ENTRY POINT
const express = require('express');
const slc = require('./slc-handler');
const app = express();
const port = 3000;

app.get('/api/signature/get', (req, res) => {
  res.send('Hello World! I am ' + process.env.ROLE);
})

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`)
})