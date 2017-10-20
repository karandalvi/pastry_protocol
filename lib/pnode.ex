defmodule PNode do

  def init(nodeID) do
    Process.flag(:trap_exit, true)
    IO.puts "Node started with ID:#{nodeID}"
    leafset = []
    rowMap = %{"0" => [], "1" => [], "2" => [], "3" => [],
               "4" => [], "5" => [], "6" => [], "7" => [],
               "8" => [], "9" => [], "A" => [], "B" => [],
               "C" => [], "D" => [], "E" => [], "F" => []}
    routingTable = buildRoutingTable(%{}, 31, rowMap)
    loop()
  end

  def loop() do
    receive do
      {:exit} -> loop()
    end
  end

  def buildRoutingTable(table, i, rowMap) when i >= 0 do
    table = Map.put(table, Integer.to_string(i), rowMap)
    buildRoutingTable(table, i-1, rowMap)
  end

  def buildRoutingTable(table, i, rowMap) when i < 0 do
    table
  end

  # Code to Insert Data into Map
  # r = Map.get(routingTable, "0")
  # r = Map.put(r, "9", ["hello"])
  # routingTable = Map.put(routingTable, "0", r)
end
