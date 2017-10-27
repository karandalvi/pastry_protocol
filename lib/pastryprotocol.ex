defmodule PastryProtocol do

  def main(input) do
    [numNodes, numRequests] = input
    numNodes = String.to_integer(numNodes)
    numRequests = String.to_integer(numRequests)
    IO.puts "Nodes   : #{numNodes}"
    IO.puts "Requests: #{numRequests}"
    nodeList = start(numNodes, [])
    # IO.inspect nodeList
    send self, {:build}
    loop(nodeList, numNodes, numRequests, [], :os.system_time(:millisecond))
  end
  # newNode = :crypto.hash(:md5, Integer.to_string(numNodes)) |> Base.encode16()

  def start(numNodes, nodeList) when numNodes > 0 do
    newNode = Integer.to_string(1000000000000000 + numNodes)
    newPid = spawn(PNode, :init, [newNode])
    send newPid, {:console, self}
    nodeList = addToSortedList(nodeList, newNode, newPid, 0)
    start(numNodes-1, nodeList)
  end

  def start(numNodes, nodeList) when numNodes <= 0 do
    nodeList
  end

  def loop(nodeList, numNodes, numRequests, hopArray, lastMessage) do
    receive do
      {:build} ->
        for x <- 0..length(nodeList)-1 do
          if (x != 0) do
            [currID, currPID] = Enum.at(nodeList, x)
            [prevID, prevPID] = Enum.at(nodeList, x-1)
            # IO.puts "#{currID} sent join to #{prevID}"

            send prevPID, {:join, currID, currPID}
          end
        end
        IO.puts "#{:os.system_time(:millisecond)}"
        # :timer.sleep(15000)
        send self, {:listen}
        loop(nodeList, numNodes, numRequests, hopArray, lastMessage)

      {:listen} ->
        if :os.system_time(:millisecond) - lastMessage > 5000 do
          IO.puts "Network Built"
          IO.puts "#{:os.system_time(:millisecond)}"
          send self, {:request}
        else
          send self, {:listen}
        end
        loop(nodeList, numNodes, numRequests, hopArray, lastMessage)

      {:running} ->
        lastMessage = :os.system_time(:millisecond)
        loop(nodeList, numNodes, numRequests, hopArray, lastMessage)

      {:request} ->
        [xID, xPID] = Enum.at(nodeList,4)
        [sID, sPID] = Enum.at(nodeList, 43)
        send xPID, {:route, sID, sPID, 0}
        loop(nodeList, numNodes, numRequests, hopArray, lastMessage)
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
end
