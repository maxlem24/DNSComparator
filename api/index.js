const express = require('express')
const app = express()
const fs = require('fs')
app.use(express.json())

app.listen(3000,() => {
console.log("API running in port 3000")
})

app.post("/result",(req,res) => {
	content=`Number of tested domains :${req.body.length}\n`
	for (const elem of req.body.results){
		content+=`${elem}\n`
	}
	filename = `results_${Date.now()}.txt`
	fs.writeFile(filename,content,(err)=>{
		if (err) {
			console.log(err)
		}
	})
	res.send("Data received").status(200)
})
