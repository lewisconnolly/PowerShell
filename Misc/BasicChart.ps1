$Dataset = [ordered]@{}

$Dataset[$key] = $value
   
# Create chart and save it
$chart = New-Chart -Dataset $Dataset -XInterval 10 -YInterval 10 -YTitle '' -Width 600 -Height 400
$chart.ChartAreas["ChartArea1"].AxisY.Maximum = 100   
$chart.ChartAreas["ChartArea1"].AxisX.IsMarginVisible = $false
$chart.ChartAreas["ChartArea1"].AxisX.MajorGrid.LineColor =  [System.Drawing.Color]::LightGray
$chart.ChartAreas["ChartArea1"].AxisY.MajorGrid.LineColor =  [System.Drawing.Color]::LightGray
$chart.ChartAreas["ChartArea1"].AxisY.TitleFont = New-Object System.Drawing.Font("Microsoft Sans Serif",12,[System.Drawing.FontStyle]::Regular)
