#!/usr/bin/env ruby

require 'tk'
require 'rexml/document'

include Math

$EPS = 1e-8

OSMFile = File.new("map.osm")
OSM = REXML::Document.new(OSMFile)

OSMRoot = OSM.root

$nodes = []
$nodesIdHash = {}

OSMRoot.elements.each("node") do |nodeElement|
	tmp = []
	tmp << nodeElement.attributes["id"].to_i
	tmp << [nodeElement.attributes["lon"].to_f, nodeElement.attributes["lat"].to_f]
	tmp << nodeElement.attributes["visible"]
	tmp << nodeElement.elements

	$nodesIdHash[tmp[0]] = $nodes.size
	$nodes << tmp
end

$ways = []

def calculateDistance(nodeId1, nodeId2)

	node1 = $nodes[$nodesIdHash[nodeId1]][1]
	node2 = $nodes[$nodesIdHash[nodeId2]][1]

=begin
	puts node1[0], node1[1]
	puts node2[0], node2[1]

	p1 = sin(node1[1] / 180 * PI) * sin(node2[1] / 180 * PI)
	p2 = cos(node1[1] / 180 * PI) * cos(node2[1] / 180 * PI) * cos((node2[0] - node1[0]) / 180 * PI)

	# puts acos(p1 + p2)

	return 6371.004 * acos(p1 + p2)
=end

	#puts node1[0], node1[1]
	#puts node2[0], node2[1]

	p1 = (node1[0] - node2[0]) ** 2
	p2 = (node1[1] - node2[1]) ** 2

	#puts sqrt(p1 + p2)

	return 6317 * sqrt(p1 + p2)
end

OSMRoot.elements.each("way") do |wayElement|
	nodesOnWay = []
	wayElement.elements.each("nd") do |wayMember|
		nodesOnWay << wayMember.attributes["ref"].to_i
	end

	1.upto(nodesOnWay.size - 1) do |i|
		tmp = []
		tmp << [nodesOnWay[i - 1], nodesOnWay[i]]
		tmp << calculateDistance(nodesOnWay[i - 1], nodesOnWay[i])
		tmp << wayElement.attributes["visible"]

		$ways << tmp
	end
end

if ARGV.size == 0 ;
	puts "-d            Display the whole map."
	puts "-d p1 p2 p3   Diplay the map from (p1%, p2%) to (p1% + p3%, p2% + p3%)."
	puts "-n            Show the list of nodes."
	puts "-s n1 n2      Calculate the shortest path from n1 to n2." 
elsif ARGV[0] == "-d";

	newARGV = ARGV + [0, 0, 100]

	StartX = newARGV[1].to_f
	StartY = newARGV[2].to_f
	EndX = newARGV[1].to_f + newARGV[3].to_f
	EndY = newARGV[2].to_f + newARGV[3].to_f


	Bound = OSMRoot.elements[1]
	minLat = Bound.attributes["minlat"].to_f
	maxLat = Bound.attributes["maxlat"].to_f
	minLon = Bound.attributes["minlon"].to_f
	maxLon = Bound.attributes["maxlon"].to_f

	minLat, maxLat = minLat + (maxLat - minLat) * StartX / 100,
	 				minLat + (maxLat - minLat) * EndX / 100

	minLon, maxLon = minLon + (maxLon - minLon) * StartY / 100,
					minLon + (maxLon - minLon) * EndY / 100


	0.upto($nodes.size - 1) do |i|
		$nodes[i][1][0] = ($nodes[i][1][0] - minLon) / (maxLon - minLon)
		$nodes[i][1][1] = ($nodes[i][1][1] - minLat) / (maxLat - minLat)
	end


	windowX = 960
	windowY = 576

	root = TkRoot.new {
		title "OSM Displayer"
	}

	canvas = TkCanvas.new(root) {
		background "light yellow"

		place(:height => windowY,
			  :width => windowX,
			  :x => 0,
			  :y => 0)
	}

	# TkcLine.new(canvas, 10, 110, 100, 110)

	$ways.each do |way|
		node1 = $nodes[$nodesIdHash[way[0][0]]]
		node2 = $nodes[$nodesIdHash[way[0][1]]]
		TkcLine.new(canvas, node1[1][0] * windowX,
							node1[1][1] * windowY,
							node2[1][0] * windowX,
							node2[1][1] * windowY, :width => 2, :fill => "pink")

=begin
		puts node1[1][0] * windowX,
			 node1[1][1] * windowY,
			 node2[1][0] * windowX,
			 node2[1][1] * windowY
=end
	end

	$nodes.each do |node|
		if node[-2] == "true" ;
			TkcOval.new(canvas, node[1][0] * windowX - 2,
								node[1][1] * windowY - 2,
								node[1][0] * windowX + 2,
								node[1][1] * windowY + 2, :fill => "purple")
		end
	end

	Tk.mainloop

elsif ARGV[0] == "-n" ;
	$nodes.each do |node|
		flag = false
		name = ""
		node[-1].each("tag") do |tag|
			if tag.attributes["k"] == "name:en" ;
				flag = true
				name = tag.attributes["v"]
			end
		end

		if flag == true ;
			print node[0], ' ', name, ?\n
		end
	end

else


	Bound = OSMRoot.elements[1]
	minLat = Bound.attributes["minlat"].to_f - 0.01
	maxLat = Bound.attributes["maxlat"].to_f + 0.01
	minLon = Bound.attributes["minlon"].to_f - 0.01
	maxLon = Bound.attributes["maxlon"].to_f + 0.01


	0.upto($nodes.size - 1) do |i|
		$nodes[i][1][0] = ($nodes[i][1][0] - minLon) / (maxLon - minLon)
		$nodes[i][1][1] = ($nodes[i][1][1] - minLat) / (maxLat - minLat)
	end


	edges = {}
	edges.default = nil

	$ways.each_with_index do |way, i|
		if edges[way[0][0]] == nil ;
			edges[way[0][0]] = []
		end
		if edges[way[0][1]] == nil ;
			edges[way[0][1]] = []
		end
		edges[way[0][0]] << [way[0][1], i]
		edges[way[0][1]] << [way[0][0], i]

		# print [way[0][0], way[0][1]], ?\n
		# print edges[way[0][0]].size

=begin
		if i == 1590 ;
			puts way[0][0]
			puts way[0][1]
		end
=end
	end

	# puts edges[824657500]

	f = {}
	f.default = 23333333.0

	vis = {}
	vis.default = false

	from = {}
	from.default = []

	NodeStart = ARGV[1].to_i
	NodeEnd = ARGV[2].to_i


	f[NodeStart] = 0
	queue = [NodeStart]
	vis[NodeStart] = true

	while queue.size > 0 do
		x = queue[0]
		queue.shift
		vis[x] = false
		# print x, ' ', from[x], ?\n

		# print edges
		edges[x].each do |edge|
			if f[x] + $ways[edge[1]][1] + $EPS < f[edge[0]] ;
				f[edge[0]] = f[x] + $ways[edge[1]][1]
				from[edge[0]] = [x, edge[1]]

				#print from[edge[0]], ?\n

				if vis[edge[0]] == false ;
					vis[edge[0]] = true
					queue << edge[0]
				end
			end
		end
	end

	if (f[NodeEnd] - 23333333.0).abs < $EPS ;
		f[NodeEnd] = "INF"
	end

	edgeUsed = {}
	edgeUsed.default = false
	if f[NodeEnd] != "INF" ;
		tmp = NodeEnd
		while tmp != NodeStart do
			edgeUsed[from[tmp][1]] = true
			# puts tmp, from[tmp][1], from[tmp][0]
			tmp = from[tmp][0]
		end
	end

	windowX = 960
	windowY = 576

	root = TkRoot.new {
		title "OSM Displayer"
	}

	canvas = TkCanvas.new(root) {
		background "light yellow"

		place(:height => windowY,
			  :width => windowX,
			  :x => 0,
			  :y => 0)
	}

	nodeUsed = {}
	nodeUsed.default = false;

	$ways.each_with_index do |way, i|
		node1 = $nodes[$nodesIdHash[way[0][0]]]
		node2 = $nodes[$nodesIdHash[way[0][1]]]

		if edgeUsed[i] == false ;
			TkcLine.new(canvas, node1[1][0] * windowX,
								node1[1][1] * windowY,
								node2[1][0] * windowX,
								node2[1][1] * windowY, :width => 2, :fill => "pink")
		end
	end

	$ways.each_with_index do |way, i|
		node1 = $nodes[$nodesIdHash[way[0][0]]]
		node2 = $nodes[$nodesIdHash[way[0][1]]]

		if edgeUsed[i] == true ;
			TkcLine.new(canvas, node1[1][0] * windowX,
								node1[1][1] * windowY,
								node2[1][0] * windowX,
								node2[1][1] * windowY, :width => 5, :fill => "black")
			nodeUsed[node1[0]] = true
			nodeUsed[node2[0]] = true
		end
	end

	$nodes.each do |node|
		# puts node[0]
		if nodeUsed[node[0]] || node[0] == NodeStart || node[0] == NodeEnd ;
			# puts '*'
			TkcOval.new(canvas, node[1][0] * windowX - 2,
								node[1][1] * windowY - 2,
								node[1][0] * windowX + 2,
								node[1][1] * windowY + 2, :fill => "black")
		end
	end

	label = TkLabel.new(root) {
		text f[NodeEnd]
		place(:x => 0, :y => windowY)
	}

	Tk.mainloop
end