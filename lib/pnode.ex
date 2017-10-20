defmodule PNode do

  def init(nodeID) do
    Process.flag(:trap_exit, true)
    # IO.puts "Node started with ID:#{nodeID}"
    leafset = []
    rowMap = %{"0" => [], "1" => [], "2" => [], "3" => [],
               "4" => [], "5" => [], "6" => [], "7" => [],
               "8" => [], "9" => [], "A" => [], "B" => [],
               "C" => [], "D" => [], "E" => [], "F" => []}
    routingTable = buildRoutingTable(%{}, 31, rowMap)
    loop(nodeID, leafset, routingTable)
  end

  def loop(nodeID, leafset, routingTable) do
    receive do
      {:join, startNode} ->
        send startNode, {:discover, self, nodeID}
        loop(nodeID, leafset, routingTable)

      {:update, senderPID, senderID, senderLeafset, senderRoutingTable} ->
        # IO.puts "#{nodeID} received routing table from #{senderID}"
        if length(leafset) < 3 do
          leafset = addToSortedList(leafset, senderID, senderPID, 0)
        end
        loop(nodeID, leafset, routingTable)

      {:discover, newNodePID, newNodeID} ->
        # Check if leafset is not full
        if length(leafset) < 3 do
          leafset = addToSortedList(leafset, newNodeID, newNodePID, 0)
          send newNodePID, {:update, self, nodeID, leafset, routingTable}
        else
          # Check min max values in leaves
          if hexToDec(newNodeID) >= hexToDec(Enum.at(Enum.at(leafset, 0), 0)) and hexToDec(newNodeID) <= hexToDec(Enum.at(Enum.at(leafset, length(leafset)-1), 0)) do
            result = findInLeaves(addToSortedList(leafset, nodeID, self, 0), newNodeID, 0)
            if (Enum.at(result, 0) == nodeID) do
              # search ends at this node
              send newNodePID, {:update, self, nodeID, leafset, routingTable}
              # update leaves
              if (hexToDec(newNodeID) < hexToDec(nodeID)) do
                # remove leftmost leaf & insert into routingTable
                deletedEntry = Enum.at(leafset, 0)
                pvalue = prefixMatch(0, Enum.at(deletedEntry,0), newNodeID)
                r = Map.get(routingTable, Integer.to_string(pvalue))
                r = Map.put(r, String.at(Enum.at(deletedEntry, 0), pvalue), deletedEntry)
                routingTable = Map.put(routingTable, Integer.to_string(pvalue), r)
                leafset = List.delete_at(leafset, 0)
              else
                # remove rightmost leaf & insert into routingTable
                deletedEntry = Enum.at(leafset, length(leafset)-1)
                pvalue = prefixMatch(0, Enum.at(deletedEntry,0), newNodeID)
                r = Map.get(routingTable, Integer.to_string(pvalue))
                r = Map.put(r, String.at(Enum.at(deletedEntry, 0), pvalue), deletedEntry)
                routingTable = Map.put(routingTable, Integer.to_string(pvalue), r)
                leafset = List.delete_at(leafset, length(leafset)-1)
              end
              # IO.inspect routingTable
              # add new discovered node to leafset
              leafset = addToSortedList(leafset, newNodeID, newNodePID, 0)
            else
              # delegate search to a leaf node
              send Enum.at(result,1), {:discover, newNodePID, newNodeID}
              send newNodePID, {:update, self, nodeID, leafset, routingTable}
            end

          else
              # if newNodeID outside leafset range, check routing table
              p = prefixMatch(0, nodeID, newNodeID)
              # routing node -> [nodeID, nodePID]
              routingNode = Map.get(Map.get(routingTable, Integer.to_string(p)), String.at(newNodeID, p))
              if routingNode == [] do
                # T U M U R
              else
                # delegate ahead
                send newNodePID, {:update, self, nodeID, leafset, routingTable}
                send Enum.at(routingNode,1), {:update, self, nodeID, leafset, routingTable}
              end
          end
        end
        # if (String.at(nodeID, 0) == "A") and
        #     (String.at(nodeID, 1) == "9") and
        #     (String.at(nodeID, 2) == "B") and
        #     (String.at(nodeID, 3) == "7") do
        #   IO.inspect leafset
        # end
        # IO.puts "#{nodeID} [#{length(leafset)}] received discover message from #{newNodeID}"

        loop(nodeID, leafset, routingTable)
    end
  end

  def buildRoutingTable(table, i, rowMap) when i >= 0 do
    table = Map.put(table, Integer.to_string(i), rowMap)
    buildRoutingTable(table, i-1, rowMap)
  end

  def buildRoutingTable(table, i, rowMap) when i < 0 do
    table
  end

  def prefixMatch(p, s1, s2) do
    if String.length(s1) == 0 do
      p
    else
      if (String.at(s1, p) == String.at(s2, p)) do
        prefixMatch(p+1, s1, s2)
      else
        p
      end
    end
  end

  def addToSortedList(list, value, pid, i) do
    if i == length(list) or hexToDec(Enum.at(Enum.at(list,i), 0)) > hexToDec(value) do
      list = List.insert_at(list, i, [value,pid])
    else
      addToSortedList(list, value, pid, i+1)
    end
  end

  def hexToDec(s) do
    {i, ""} = Integer.parse(s, 16)
    i
  end

  def findInLeaves(leafset, value, i) do
    if i == length(leafset) do
      Enum.at(leafset, i-1)
    else
      if hexToDec(Enum.at(Enum.at(leafset,i), 0)) > hexToDec(value) do
        if (i == 0) do
          Enum.at(leafset,0)
        else
          if (abs(hexToDec(value) - hexToDec(Enum.at(Enum.at(leafset, i-1), 0)))) <=
            (abs(hexToDec(value) - hexToDec(Enum.at(Enum.at(leafset, i), 0)))) do
             Enum.at(leafset, i-1)
          else
             Enum.at(leafset, i)
          end
        end
      else
        findInLeaves(leafset, value, i+1)
      end
    end
  end
  # Code to Insert Data into Map
  # r = Map.get(routingTable, "0")
  # r = Map.put(r, "9", ["hello"])
  # routingTable = Map.put(routingTable, "0", r)
end
