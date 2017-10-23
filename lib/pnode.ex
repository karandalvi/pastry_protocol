defmodule PNode do

  def init(nodeID, nodename) do
    Process.flag(:trap_exit, true)
    # IO.puts "Node started with ID:#{nodeID}"
    # nodename = String.at(nodename, length(nodename)-3) <> String.at(nodename, length(nodename)-2) <> String.at(nodename, length(nodename)-1)
    leafset = [] #TODO: Add self node to leafset?
    rowMap = %{"0" => [], "1" => [], "2" => [], "3" => [],
               "4" => [], "5" => [], "6" => [], "7" => [],
               "8" => [], "9" => [], "A" => [], "B" => [],
               "C" => [], "D" => [], "E" => [], "F" => []}
    routingTable = buildRoutingTable(%{}, 15, rowMap) #TODO: Change to 30
    loop(nodeID, leafset, routingTable, [], nodename)
  end

  def loop(nodeID, leafset, routingTable, console, nodename) do
    receive do

      {:init, startPID, nodeList, pidList} ->
        for x <- 1..length(nodeList) do
          if prefixMatch(0, nodeID, Enum.at(nodeList, x)) == 15 do
            send self, {:addLeaf, Enum.at(nodeList, x), Enum.at(pidList, x)}
          else
            send self, {:addRoute, Enum.at(nodeList, x), Enum.at(pidList, x)}
          end
        end
        send startPID, {:join, nodeID, self, nodename}
        loop(nodeID, leafset, routingTable, console, nodename)

      {:init, startPID} ->
        send startPID, {:join, nodeID, self, nodename}
        loop(nodeID, leafset, routingTable, console, nodename)

      {:state, senderID, senderPID, senderLeafset, senderRoutingTable} ->
        if senderID != nodeID do
          allNodes = Enum.uniq(buildList(senderRoutingTable, [], 15) ++ senderLeafset ++ [[senderID, senderPID]])
          for x <- allNodes do
            [xID, xPID] = x
            if prefixMatch(0, nodeID, xID) == 15 do
              send self, {:addLeaf, xID, xPID}
            else
              send self, {:addRoute, xID, xPID}
            end
          end
        end
        loop(nodeID, leafset, routingTable, console, nodename)

      {:addLeaf, leafID, leafPID} ->
        leafset = addToSortedList(leafset, leafID, leafPID, 0)
        # IO.inspect leafset, label: "Node #{nodeID} -> "
        loop(nodeID, Enum.uniq(leafset), routingTable, console, nodename)

      {:addRoute, xID, xPID} ->
        pm = prefixMatch(0, nodeID, xID)
        row = Map.get(routingTable, Integer.to_string(pm))
        row = Map.put(row, String.at(xID, pm), [xID, xPID])
        routingTable = Map.put(routingTable, Integer.to_string(pm), row)
        # IO.inspect routingTable, label: "Node #{nodeID} -> "
        loop(nodeID, leafset, routingTable, console, nodename)

      {:join, joinID, joinPID, joinName} ->
        send joinPID, {:state, nodeID, self, leafset, routingTable}
        if (nodeID == joinID) do
          IO.puts "#1 Node received join message from itself"
        else
          pm = prefixMatch(0, nodeID, joinID)
          if length(leafset) > 0
          and hexToDec(Enum.at(Enum.at(leafset,0),0)) <= hexToDec(joinID)
          and hexToDec(Enum.at(Enum.at(leafset,length(leafset)-1), 0)) <= hexToDec(joinID) do
            result = findInLeaves(leafset, joinID, 0)
            send Enum.at(result,1), {:join, joinID, joinPID, joinName}
          else
            row = Map.get(routingTable, Integer.to_string(pm))
            entry = Map.get(row, String.at(joinID, pm))
            if length(entry) > 0 do
              send Enum.at(entry, 1), {:join, joinID, joinPID, joinName}
            else
              allNodes = buildList(routingTable, [], 15) #TODO: Change to 30
              allNodes = allNodes ++ leafset
              for x <- allNodes do
                [xID, xPID] = x
                if prefixMatch(0, xID,joinID) >= prefixMatch(0, nodeID, joinID) do
                  send xPID, {:join, joinID, joinPID, joinName}
                end
              end
            end
          end
        end
        loop(nodeID, leafset, routingTable, console, nodename)

      {:route, searchID, searchPID, searchName, hop} ->
        IO.puts "#{hop} - #{nodeID} - #{searchID}"
        IO.inspect leafset
        IO.inspect routingTable
        :timer.sleep(2000)
        if (nodeID == searchID) do
          IO.puts "#1 Search terminated"
          send console, {:hopCount, hop}
        else
          pm = prefixMatch(0, nodeID, searchID)
          if length(leafset) > 0
          and hexToDec(Enum.at(Enum.at(leafset,0),0)) <= hexToDec(searchID)
          and hexToDec(Enum.at(Enum.at(leafset,length(leafset)-1), 0)) <= hexToDec(searchID) do
            result = findInLeaves(leafset, searchID, 0)
            send Enum.at(result,1), {:route, searchID, searchPID, searchName, hop+1}
          else
            row = Map.get(routingTable, Integer.to_string(pm))
            entry = Map.get(row, String.at(searchID, pm))
            if length(entry) > 0 do
              send Enum.at(entry, 1), {:route, searchID, searchPID, searchName, hop+1}
            else
              allNodes = buildList(routingTable, [], 15) #TODO: Change to 30
              allNodes = allNodes ++ leafset
              for x <- allNodes do
                [xID, xPID] = x
                if prefixMatch(0, xID,searchID) >= prefixMatch(0, nodeID, searchID) do
                  send xPID, {:route, searchID, searchPID, searchName, hop+1}
                end
              end
            end
          end
        end
        loop(nodeID, leafset, routingTable, console, nodename)

      {:console, id} ->
        loop(nodeID, leafset, routingTable, id, nodename)

      {:Oldjoin, startNode, startNodeName} ->
        IO.puts "#{nodeID} sending discover msg to #{startNodeName}"
        send startNode, {:discover, self, nodeID, nodename, 0, 0}
        loop(nodeID, leafset, routingTable, console, nodename)

      {:update, senderPID, senderID, senderName, senderLeafset, senderRoutingTable, gossipNumber} ->
        if gossipNumber < 4 do

          # IO.puts "#{senderName} -> table -> #{nodename}"
          # send console, {:running}
          allNodes = buildList(senderRoutingTable, [], 30) ++ senderLeafset

          # if (nodename == "1000000000000002"), do: IO.inspect length(buildList(senderRoutingTable, [], 30))
          for x <- allNodes do
            :timer.sleep(100)
            [nID, nPID] = x
            if nID != nodeID, do: send self, {:discover, nPID, nID, nodename, gossipNumber, 0}
            # :timer.sleep(100)
          end
        end
        loop(nodeID, leafset, routingTable, console, nodename)

      {:discover, newNodePID, newNodeID, newNodeName, selfMessage, hop} ->
        if selfMessage == 0, do: IO.puts "1 #{nodeID} receive discover msg from #{newNodeID}"
        if selfMessage > 0, do: IO.puts "1 #{nodeID} receive update msg from #{newNodeID}"
        # pos = Enum.find_index(leafset, fn(x) -> Enum.at(x,0) == nodeID end)
        # if (hexToDec(newNodeID) < hexToDec(nodeID) and pos <= 5) do
        # if selfMessage == 0, do: IO.puts "#{newNodeName} -> discover -> #{nodename}"
        leafset = Enum.uniq(leafset)  #TODO remove
        if (nodeID == newNodeID) do
          IO.puts "A1 Search for #{newNodeID} terminated at #{nodeID}"
        else
          # Check if leafset is not full
          if length(leafset) < 6 do
            result = findInLeaves(leafset, newNodeID, 0)
            if Enum.at(result, 0) != newNodeID, do: leafset = addToSortedList(leafset, newNodeID, newNodePID, 0)

            if (Enum.at(result, 0) != nodeID) do
              if selfMessage == 0, do: IO.puts "2 #{nodeID} sending discover #{newNodeID} to #{Enum.at(result, 0)}"
              send Enum.at(result,1), {:discover, newNodePID, newNodeID, newNodeName,selfMessage, hop + 1}
            else
             IO.puts "A2 Search for #{newNodeID} terminated at #{nodeID}"
            end
          else

            pos = Enum.find_index(leafset, fn(x) -> Enum.at(x,0) == nodeID end)
            # if nodename == "10000000000000000000000000000457", do: IO.puts "#{newNodeName} -- #{pos}"
            if (hexToDec(newNodeID) < hexToDec(nodeID) and pos < 5) or (hexToDec(newNodeID) > hexToDec(nodeID) and length(leafset) - pos <= 5) do
              result = findInLeaves(leafset, newNodeID, 0)
              if (Enum.at(result, 0) != nodeID) and (Enum.at(result, 0) != newNodeID) do
                if Enum.at(result, 0) != newNodeID, do: leafset = addToSortedList(leafset, newNodeID, newNodePID, 0)
                IO.puts "3 #{nodeID} sending discover #{newNodeID} to #{Enum.at(result, 0)}"
                if selfMessage == 0, do: send Enum.at(result,1), {:discover, newNodePID, newNodeID, newNodeName,selfMessage, hop + 1}
              else
                IO.puts "A3 Search for #{newNodeID} terminated at #{nodeID}"
              end
            else

            # Check min max values in leaves
            if hexToDec(newNodeID) >= hexToDec(Enum.at(Enum.at(leafset, 0), 0)) and hexToDec(newNodeID) <= hexToDec(Enum.at(Enum.at(leafset, length(leafset)-1), 0)) do
              result = findInLeaves(leafset, newNodeID, 0)

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
              # add new discovered node to leafset
              leafset = Enum.uniq(addToSortedList(leafset, newNodeID, newNodePID, 0))

              if (Enum.at(result, 0) != nodeID) do

                IO.puts "4 #{nodeID} sending discover #{newNodeID} to #{Enum.at(result, 0)}"
                if selfMessage == 0, do: send Enum.at(result,1), {:discover, newNodePID, newNodeID, newNodeName,selfMessage, hop + 1}
              else
                IO.puts "A4 Search for #{newNodeID} terminated at #{nodeID}"
              end

            else #outside leafset range

                # if newNodeID outside leafset range, check routing table
                p = prefixMatch(0, nodeID, newNodeID)
                routingNode = Map.get(Map.get(routingTable, Integer.to_string(p)), String.at(newNodeID, p))

                if routingNode == [] do
                  # TUMUR
                  allNodes = buildSortedList(routingTable, [], 30)
                  allNodes = mergeSortedLists([], allNodes, leafset)
                  # allNodes = mergeSortedLists([], allNodes, [[nodeID, self]])
                  result = findInLeaves(allNodes, newNodeID, 0)
                  if Enum.at(result, 0) != nodeID do

                    IO.puts "5 #{nodeID} sending discover #{newNodeID} to #{Enum.at(result, 0)}"
                    if selfMessage == 0, do: send Enum.at(result,1), {:discover, newNodePID, newNodeID, newNodeName, selfMessage, hop + 1}
                  else
                    IO.puts "A5 Search for #{newNodeID} terminated at #{nodeID}"
                  end
                  # add new node to routing table
                  r = Map.get(routingTable, Integer.to_string(p))
                  r = Map.put(r, String.at(newNodeID, p), [newNodeID, newNodePID])
                  routingTable = Map.put(routingTable, Integer.to_string(p), r)
                else
                  # delegate discovery to node found in routing table
                  IO.puts "7 #{nodeID} sending discover #{newNodeID} to #{Enum.at(routingNode, 0)}"
                  if selfMessage == 0, do: send Enum.at(routingNode,1), {:discover, newNodePID, newNodeID, newNodeName, selfMessage, hop + 1}
                end
            end
          end
          end
        end

        # if nodename == "1000000000000002", do: IO.inspect leafset
        # send newNodePID, {:update, self, nodeID, nodename, leafset, routingTable, selfMessage + 1}
        # if selfMessage == 0, do: send newNodePID, {:update, self, nodeID, nodename, leafset, routingTable, 0}

        if selfMessage >= 0 and selfMessage < 100 and nodeID != newNodeID do
          IO.inspect leafset, label: "6 #{nodeID} sending update to #{newNodeID} with"
          send newNodePID, {:update, self, nodeID, nodename, leafset, routingTable, selfMessage + 1}
        end

        IO.inspect leafset, label: "#### #{nodeID} --> "
        loop(nodeID, leafset, routingTable, console, nodename)

        {:Oldfind, newNodePID, newNodeID, hop} ->
          if (nodeID == newNodeID) do
            IO.puts "Found at #{nodeID}"
            send console, {:collectHopNumber, hop}
          end
          loop(nodeID, leafset, routingTable, console, nodename)

        {:sendRequest, nPID, nID} ->
          send self, {:discover, nPID, nID, 0, 2, 0}
          loop(nodeID, leafset, routingTable, console, nodename)

        {:print} ->
          # IO.puts "#{nodeID} | #{length(leafset)} | #{length(buildList(routingTable, [], 30))}"
          # IO.puts "#{nodeID} | #{length(leafset)} | #{length(buildList(routingTable, [], 30))} | #{Enum.at(Enum.at(leafset, 0), 0)} | #{Enum.at(Enum.at(leafset, length(leafset) - 1), 0)}"
          loop(nodeID, leafset, routingTable, console, nodename)
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

  def getDigit (i) do
    dmap = %{0 => "0", 1 => "1", 2 => "2", 3 => "3",
      4 => "4", 5 => "5", 6 => "6", 7 => "7",
      8 => "8", 9 => "9", 10 => "A", 11 => "B",
      12 => "C", 13 => "D", 14 => "E", 15 => "F"}
    Map.get(dmap, i)
  end

  def buildList(routingTable, list, rowIndex) when rowIndex >= 0 do
    row = Map.get(routingTable, Integer.to_string(rowIndex))
    rowList = buildRowList(row, [], 15)
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
