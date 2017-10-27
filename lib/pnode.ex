defmodule PNode do

  def init(nodeID) do
    Process.flag(:trap_exit, true)
    leafset = [[nodeID, self]]
    rowMap = %{"0" => [], "1" => [], "2" => [], "3" => [],
               "4" => [], "5" => [], "6" => [], "7" => [],
               "8" => [], "9" => []} #TODO: Change to A-F
              #  , "A" => [], "B" => [],
              #  "C" => [], "D" => [], "E" => [], "F" => []}
    routingTable = buildRoutingTable(%{}, 15, rowMap)
    loop(nodeID, leafset, routingTable, [], %{})
  end

  def loop(nodeID, leafset, routingTable, console, map) do
    receive do
      {:console, senderID} ->
        loop(nodeID, leafset, routingTable, senderID, map)

      {:state, senderID, senderPID, senderLeafset, senderRoutingTable} ->
        send console, {:running}
        # IO.puts "#{nodeID} receives state from #{senderID}"
        if senderID != nodeID do
          allNodes = Enum.uniq(buildList(senderRoutingTable, [], 15) ++ senderLeafset)
          myNodes = Enum.uniq(buildList(routingTable, [], 15) ++ leafset)
          newNodes = allNodes -- myNodes
          for n <- newNodes do
            [nID, nPID] = n
            send self, {:addLeaf, nID, nPID}
          end
          # send self, {:sendState, senderID, senderPID}
          for n <- newNodes do
            [nID, nPID] = n
            send self, {:sendState, nID, nPID}
          end
        end
        loop(nodeID, leafset, routingTable, console, map)

      {:sendState, newID, newPID} ->
        # IO.puts "#{nodeID} sent next state to #{newID}"
        count = Map.get(map, newID)
        if count == nil do
          map = Map.put(map, newID, 1)
          send newPID, {:state, nodeID, self, leafset, routingTable}
          loop(nodeID, leafset, routingTable, console, map)
        else
          if (count < 1) do
            map = Map.put(map, newID, count+1)
            send newPID, {:state, nodeID, self, leafset, routingTable}
            loop(nodeID, leafset, routingTable, console, map)
          else
            loop(nodeID, leafset, routingTable, console, map)
          end
        end

      {:addLeaf, leafID, leafPID} ->
        # IO.puts "#{nodeID} updating state"
        leafset = leafset -- [[leafID, leafPID]]
        pos = Enum.find_index(leafset, fn(x) -> Enum.at(x,0) == nodeID end)
        if (length(leafset) < 5) or
        (hexToDec(leafID) < hexToDec(nodeID) and pos < 4) or
        (hexToDec(leafID) > hexToDec(nodeID) and (length(leafset)-1-pos) < 4) do
          leafset = addToSortedList(leafset, leafID, leafPID, 0)
        else
          if (hexToDec(leafID) > hexToDec(Enum.at(Enum.at(leafset, 0), 0)) and
              hexToDec(leafID) < hexToDec(nodeID) and
              pos >= 4)
              or
              (hexToDec(leafID) < hexToDec(Enum.at(Enum.at(leafset, length(leafset)-1), 0)) and
              hexToDec(leafID) > hexToDec(nodeID) and
              (length(leafset)-1) - pos >= 4) do

            if hexToDec(leafID) < hexToDec(nodeID) do
              send self, {:addRoute, Enum.at(Enum.at(leafset, 0),0), Enum.at(Enum.at(leafset, 0),1)}
              leafset = List.delete_at(leafset, 0)
              leafset = addToSortedList(leafset, leafID, leafPID, 0)
              loop(nodeID, leafset, routingTable, console, map)
            else
              send self, {:addRoute, Enum.at(Enum.at(leafset, length(leafset)-1),0), Enum.at(Enum.at(leafset, length(leafset)-1),1)}
              leafset = List.delete_at(leafset, length(leafset)-1)
              leafset = addToSortedList(leafset, leafID, leafPID, 0)
              loop(nodeID, leafset, routingTable, console, map)
            end
          else
            send self, {:addRoute, leafID, leafPID}
          end
        end

        # if nodeID == "1000000000002570", do: IO.inspect leafset, label: "Leafset #{nodeID} -> "
        loop(nodeID, leafset, routingTable, console, map)


      {:deleteLeaf, leafID, leafPID} ->
        leafset = leafset -- [[leafID, leafPID]]
        loop(nodeID, leafset, routingTable, console, map)

      {:addRoute, xID, xPID} ->
        pm = prefixMatch(0, nodeID, xID)
        row = Map.get(routingTable, Integer.to_string(pm))
        row = Map.put(row, String.at(xID, pm), [xID, xPID])
        routingTable = Map.put(routingTable, Integer.to_string(pm), row)
        loop(nodeID, leafset, routingTable, console, map)

      {:join, joinID, joinPID} ->
        if (nodeID == joinID) do
          # IO.puts "### 01 - #{nodeID} received join message from itself"
        else
          pm = prefixMatch(0, nodeID, joinID)
          if length(leafset) > 0
          and hexToDec(Enum.at(Enum.at(leafset,0),0)) <= hexToDec(joinID)
          and hexToDec(Enum.at(Enum.at(leafset,length(leafset)-1), 0)) >= hexToDec(joinID) do
            result = findInLeaves(leafset, joinID, 0)  #TODO: Test this function
            # IO.puts "#{nodeID} forwarding #{joinID} join to #{Enum.at(result,0)}"
            send Enum.at(result,1), {:join, joinID, joinPID}
          else
            row = Map.get(routingTable, Integer.to_string(pm))
            entry = Map.get(row, String.at(joinID, pm))
            if length(entry) > 0 do
              # IO.puts "#{nodeID} forwarding #{joinID} join to #{Enum.at(entry,0)}"
              send Enum.at(entry, 1), {:join, joinID, joinPID}
            else
              allNodes = buildList(routingTable, [], 15) #TODO: Change to 30
              allNodes = allNodes ++ leafset

              nextHop = findInRoutingTable(allNodes, pm, abs(hexToDec(joinID) - hexToDec(nodeID)), joinID, [])
              if (nextHop == []) do
                # IO.puts "Search for #{joinID} has terminated at #{nodeID}"
              else
                for x <- nextHop do
                  [xID, xPID] = x
                  # IO.puts "#{nodeID} forwarding #{joinID} join to #{xID}"
                  send xPID, {:join, joinID, joinPID}
                end
              end
            end
          end
        end

        # IO.puts "#{nodeID} sent state to #{joinID}"
        send joinPID, {:state, nodeID, self, leafset, routingTable}
        loop(nodeID, leafset, routingTable, console, map)

      {:route, searchID, searchPID, hop} ->
        # IO.puts "#{hop} - #{nodeID} - #{searchID}"
        # IO.inspect leafset
        # IO.inspect routingTable
        if (nodeID == searchID) do
          send console, {:hop, hop}
        else
          pm = prefixMatch(0, nodeID, searchID)
          if length(leafset) > 0
          and hexToDec(Enum.at(Enum.at(leafset,0),0)) <= hexToDec(searchID)
          and hexToDec(Enum.at(Enum.at(leafset,length(leafset)-1), 0)) >= hexToDec(searchID) do
            result = findInLeaves(leafset, searchID, 0)
            send Enum.at(result,1), {:route, searchID, searchPID, hop+1}
          else
            row = Map.get(routingTable, Integer.to_string(pm))
            entry = Map.get(row, String.at(searchID, pm))
            if length(entry) > 0 do
              # IO.puts "forwarding route to #{Enum.at(entry, 0)}"
              send Enum.at(entry, 1), {:route, searchID, searchPID, hop+1}
            else

              allNodes = buildList(routingTable, [], 15) #TODO: Change to 30
              allNodes = allNodes ++ leafset
              nextHop = findInRoutingTable(allNodes, pm, abs(hexToDec(searchID) - hexToDec(nodeID)), searchID, [])
              if (nextHop == []) do
                send console, {:hop, hop}
              else
                for x <- nextHop do
                  [xID, xPID] = x
                  send xPID, {:route, searchID, searchPID, hop+1}
                end
              end
            end

          end
        end
        loop(nodeID, leafset, routingTable, console, map)

    end
  end

  def findInRoutingTable(allNodes, pm, distance, joinID, hopList) when allNodes != [] do
    [xID, xPID] = hd(allNodes)
    if prefixMatch(0, xID, joinID) >= pm
    and abs(hexToDec(joinID) - hexToDec(xID)) < distance do
      hopList = hopList ++ [[xID, xPID]]
    end
    findInRoutingTable(tl(allNodes), pm, distance, joinID, hopList)
  end

  def findInRoutingTable(allNodes, pm, distance, joinID, hopList) when allNodes == [] do
    hopList
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

  def getDigit (i) do
    dmap = %{0 => "0", 1 => "1", 2 => "2", 3 => "3",
      4 => "4", 5 => "5", 6 => "6", 7 => "7",
      8 => "8", 9 => "9", 10 => "A", 11 => "B",
      12 => "C", 13 => "D", 14 => "E", 15 => "F"}
    Map.get(dmap, i)
  end

  def buildList(routingTable, list, rowIndex) when rowIndex >= 0 do
    row = Map.get(routingTable, Integer.to_string(rowIndex))
    rowList = buildRowList(row, [], 9) #TODO Change to 15
    if (rowList != []), do: list = list ++ rowList
    buildList(routingTable, list, rowIndex - 1)
  end

  def buildList(routingTable, list, rowIndex) when rowIndex < 0 do
    list
  end

  def buildRowList(routingRow, list, digitIndex) when digitIndex >= 0 do
    entry = Map.get(routingRow, getDigit(digitIndex))

    if (entry != []), do: list = List.insert_at(list, 0, entry)
    buildRowList(routingRow, list, digitIndex - 1)
  end

  def buildRowList(routingRow, list, digitIndex) when digitIndex < 0 do
    list
  end


  def buildSortedList(routingTable, list, rowIndex) when rowIndex >= 0 do
    row = Map.get(routingTable, Integer.to_string(rowIndex))
    rowList = buildSortedRowList(row, [], 15)
    if (rowList != []) do
        list = mergeSortedLists([], list, rowList)
    end
    buildSortedList(routingTable, list, rowIndex - 1)
  end

  def buildSortedList(routingTable, list, rowIndex) when rowIndex < 0 do
    list
  end

  def buildSortedRowList(routingRow, list, digitIndex) when digitIndex >= 0 do
    entry = Map.get(routingRow, getDigit(digitIndex))
    if (entry != []), do: list = addToSortedList(list, Enum.at(entry, 0), Enum.at(entry, 1), 0)
    buildSortedRowList(routingRow, list, digitIndex - 1)
  end

  def buildSortedRowList(routingRow, list, digitIndex) when digitIndex < 0 do
    list
  end

  def mergeSortedLists(sortedlist, list1, list2) do
    if (length(list1) == 0 and length(list2) == 0) do
      sortedlist
    else
      if length(list1) == 0 do
        sortedlist ++ list2
      else
        if length(list2) == 0 do
          sortedlist ++ list1
        else
          if hexToDec(Enum.at(hd(list1), 0)) < hexToDec(Enum.at(hd(list2), 0)) do
            sortedlist = sortedlist ++ [hd(list1)]
            mergeSortedLists(sortedlist, tl(list1), list2)
          else
            sortedlist = sortedlist ++ [hd(list2)]
            mergeSortedLists(sortedlist, list1, tl(list2))
          end
        end
      end
    end
  end

end
