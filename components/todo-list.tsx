"use client"

import { useState, useEffect, useRef } from "react"
import { Plus, Trash2 } from "lucide-react"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"

type Todo = {
  id: string
  text: string
  completed: boolean
}

export function TodoList() {
  const [mounted, setMounted] = useState(false)
  const [todos, setTodos] = useState<Todo[]>([])
  const [newTodo, setNewTodo] = useState("")
  const [activeFilter, setActiveFilter] = useState("all")
  const idCounter = useRef(0)

  // Only run client-side code after hydration
  useEffect(() => {
    setMounted(true)
    
    // Load todos from localStorage
    const storedTodos = localStorage.getItem("todos")
    if (storedTodos) {
      try {
        const parsedTodos = JSON.parse(storedTodos)
        setTodos(parsedTodos)
        
        // Set the idCounter to the highest ID + 1
        const ids = parsedTodos.map((todo: Todo) => {
          const id = parseInt(todo.id, 10);
          return isNaN(id) ? 0 : id;
        });
        idCounter.current = ids.length > 0 ? Math.max(...ids) + 1 : 0;
      } catch (e) {
        console.error("Failed to parse todos from localStorage:", e);
        localStorage.removeItem("todos"); // Clear invalid data
      }
    }
  }, [])

  // Save todos to localStorage whenever they change
  useEffect(() => {
    if (mounted && todos.length > 0) {
      localStorage.setItem("todos", JSON.stringify(todos));
    }
  }, [todos, mounted]);

  const addTodo = () => {
    if (newTodo.trim() === "") return

    const newTodoItem: Todo = {
      id: (idCounter.current++).toString(),
      text: newTodo,
      completed: false,
    }

    setTodos([...todos, newTodoItem])
    setNewTodo("")
  }

  const toggleTodo = (id: string) => {
    setTodos(todos.map((todo) => (todo.id === id ? { ...todo, completed: !todo.completed } : todo)))
  }

  const deleteTodo = (id: string) => {
    setTodos(todos.filter((todo) => todo.id !== id))
  }

  const clearCompleted = () => {
    setTodos(todos.filter((todo) => !todo.completed))
  }

  const filteredTodos = todos.filter((todo) => {
    if (activeFilter === "active") return !todo.completed
    if (activeFilter === "completed") return todo.completed
    return true
  })

  const activeTodosCount = todos.filter((todo) => !todo.completed).length

  // Prevent hydration issues by not rendering until client-side
  if (!mounted) {
    return <div className="w-full max-w-md h-96 flex items-center justify-center">Loading...</div>
  }

  return (
    <Card className="w-full max-w-md shadow-lg">
      <CardHeader>
        <CardTitle className="text-2xl text-center">Todo List</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex space-x-2 mb-6">
          <Input
            placeholder="What needs to be done?"
            value={newTodo}
            onChange={(e) => setNewTodo(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") addTodo()
            }}
            className="flex-1"
          />
          <Button onClick={addTodo} size="icon">
            <Plus className="h-4 w-4" />
          </Button>
        </div>

        <Tabs defaultValue="all" onValueChange={setActiveFilter}>
          <TabsList className="grid w-full grid-cols-3 mb-4">
            <TabsTrigger value="all">All</TabsTrigger>
            <TabsTrigger value="active">Active</TabsTrigger>
            <TabsTrigger value="completed">Completed</TabsTrigger>
          </TabsList>

          <TabsContent value="all" className="mt-0">
            <TodoItems todos={filteredTodos} onToggle={toggleTodo} onDelete={deleteTodo} />
          </TabsContent>
          <TabsContent value="active" className="mt-0">
            <TodoItems todos={filteredTodos} onToggle={toggleTodo} onDelete={deleteTodo} />
          </TabsContent>
          <TabsContent value="completed" className="mt-0">
            <TodoItems todos={filteredTodos} onToggle={toggleTodo} onDelete={deleteTodo} />
          </TabsContent>
        </Tabs>
      </CardContent>

      <CardFooter className="flex justify-between border-t pt-4">
        <p className="text-sm text-muted-foreground">
          {activeTodosCount} {activeTodosCount === 1 ? "item" : "items"} left
        </p>
        <Button variant="outline" size="sm" onClick={clearCompleted}>
          Clear completed
        </Button>
      </CardFooter>
    </Card>
  )
}

interface TodoItemsProps {
  todos: Todo[]
  onToggle: (id: string) => void
  onDelete: (id: string) => void
}

function TodoItems({ todos, onToggle, onDelete }: TodoItemsProps) {
  if (todos.length === 0) {
    return <p className="text-center text-muted-foreground py-4">No todos to display</p>
  }

  return (
    <ul className="space-y-2">
      {todos.map((todo) => (
        <li
          key={todo.id}
          className="flex items-center justify-between p-3 border rounded-md group hover:bg-muted/50 transition-colors"
        >
          <div className="flex items-center gap-3">
            <Checkbox id={`todo-${todo.id}`} checked={todo.completed} onCheckedChange={() => onToggle(todo.id)} />
            <label
              htmlFor={`todo-${todo.id}`}
              className={`text-sm ${todo.completed ? "line-through text-muted-foreground" : ""}`}
            >
              {todo.text}
            </label>
          </div>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => onDelete(todo.id)}
            className="opacity-0 group-hover:opacity-100 transition-opacity"
          >
            <Trash2 className="h-4 w-4" />
            <span className="sr-only">Delete</span>
          </Button>
        </li>
      ))}
    </ul>
  )
}
