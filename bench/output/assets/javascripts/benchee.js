var RUN_TIME_AXIS_TITLE = "Run Time in microseconds";

var runtimeHistogramData = function(runTimeData) {
  var data = [
    {
      type: "histogram",
      x: runTimeData
    }
  ];

  return data;
};

var drawGraph = function(node, data, layout) {
  Plotly.newPlot(node, data, layout, { displaylogo: false });
};

var rawRunTimeData = function(runTimeData) {

  var data = [
    {
      y: runTimeData,
      type: "bar"
    }
  ];

  return data;
};

var ipsComparisonData = function(statistics, sortOrder) {
  var names = [];
  var ips = [];
  var errors = [];
  sortOrder.forEach(function(name) {
    names.push(name);
    ips.push(statistics[name]["ips"]);
    errors.push(statistics[name]["std_dev_ips"]);
  });

  var data = [
    {
      type: "bar",
      x: names,
      y: ips,
      error_y: {
        type: "data",
        array: errors,
        visible: true
      }
    }
  ];

  return data;
};

var boxPlotData = function(runTimes, sortOrder) {
  var data = sortOrder.map(function(name) {
    return {
      name: name,
      y: runTimes[name],
      type: "box"
    };
  });

  return data;
};

window.drawIpsComparisonChart = function(statistics, sortOrder, inputHeadline) {
  var ipsNode = document.getElementById("ips-comparison");
  var layout = {
    title: "Average Iterations per Second" + inputHeadline,
    yaxis: { title: "Iterations per Second" }
  };
  drawGraph(ipsNode, ipsComparisonData(statistics, sortOrder), layout);
};

window.drawComparisonBoxPlot = function(runTimes, sortOrder, inputHeadline) {
  var boxNode = document.getElementById("box-plot");
  var layout = {
    title: "Run Time Boxplot" + inputHeadline,
    yaxis: { title: RUN_TIME_AXIS_TITLE }
  };
  drawGraph(boxNode, boxPlotData(runTimes, sortOrder), layout);
};

window.drawRawRunTimeCharts = function(runTimes, inputHeadline) {
  var runTimeNode = document.getElementById("raw-run-times");
  var jobName = runTimeNode.getAttribute("data-job-name");
  var layout = {
    title: jobName + " Raw Run Times" + inputHeadline,
    yaxis: { title: RUN_TIME_AXIS_TITLE },
    xaxis: { title: "Sample number"}
  };
  drawGraph(runTimeNode, rawRunTimeData(runTimes), layout);
};

window.drawRunTimeHistograms = function(runTimes, inputHeadline) {
  var runTimeHistogramNode = document.getElementById("sorted-run-times");
  var jobName = runTimeHistogramNode.getAttribute("data-job-name");
  var layout = {
    title: jobName + " Run Times Histogram" + inputHeadline,
    xaxis: { title: "Raw run time buckets in microseconds" },
    yaxis: { title: "Occurences in sample" }
  };
  drawGraph(runTimeHistogramNode, runtimeHistogramData(runTimes), layout);
};
