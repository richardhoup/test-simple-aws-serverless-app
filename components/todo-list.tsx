"use client"

import { useState, useEffect } from "react"
import { Plus, Trash2 } from "lucide-react"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"

type Todo = {
  id: string
  text: string
  completed: boolean
}

type FilterType = "all" | "active" | "completed"

export function TodoList() {
  const [todos, setTodos] = useState<Todo[]>([])
  const [newTodo, setNewTodo] = useState("")
  const [activeFilter, setActiveFilter] = useState<FilterType>("all")

  // Load todos from localStorage on initial render
  useEffect(() => {
    const storedTodos = localStorage.getItem("todos")
    if (storedTodos) {
      setTodos(JSON.parse(storedTodos))
    }
  }, [])

  // Save todos to localStorage whenever they change
  useEffect(() => {
    localStorage.setItem("todos", JSON.stringify(todos))
  }, [todos])

  const addTodo = () => {
    if (newTodo.trim() === "") return

    const newTodoItem: Todo = {
      id: Date.now().toString(),
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

  const deleteAllTodos = () => {
    setTodos([])
  }

  const filteredTodos = todos.filter((todo) => {
    if (activeFilter === "active") return !todo.completed
    if (activeFilter === "completed") return todo.completed
    return true
  })

  const activeTodosCount = todos.filter((todo) => !todo.completed).length

  return (
    <Card className="w-full max-w-sm shadow-md">
      <CardHeader className="pb-2 pt-3 px-3">
        <CardTitle className="text-lg text-center">Todo List</CardTitle>
      </CardHeader>
      <CardContent className="px-3 py-2 space-y-3">
        <div className="flex space-x-1">
          <Input
            placeholder="What needs to be done?"
            value={newTodo}
            onChange={(e) => setNewTodo(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") addTodo()
            }}
            className="flex-1 h-8 text-sm"
          />
          <Button onClick={addTodo} size="icon" className="h-8 w-8">
            <Plus className="h-3 w-3" />
          </Button>
        </div>

        <div className="space-y-2">
          <div className="flex border-b w-full">
            {(["all", "active", "completed"] as const).map((filter) => (
              <button
                key={filter}
                onClick={() => setActiveFilter(filter)}
                className={`flex-1 px-3 py-1.5 text-xs font-medium capitalize transition-colors relative text-center ${
                  activeFilter === filter ? "text-primary" : "text-muted-foreground hover:text-foreground"
                }`}
              >
                {filter}
                {activeFilter === filter && <span className="absolute bottom-0 left-0 right-0 h-0.5 bg-primary" />}
              </button>
            ))}
          </div>

          <div className="min-h-[100px]">
            <TodoItems todos={filteredTodos} onToggle={toggleTodo} onDelete={deleteTodo} />
          </div>
        </div>
      </CardContent>

      <CardFooter className="flex justify-between border-t pt-2 pb-2 px-3">
        <div className="flex items-center gap-1">
          <p className="text-xs text-muted-foreground">
            {activeTodosCount} {activeTodosCount === 1 ? "item" : "items"} left
          </p>
          <Button
            variant="destructive"
            size="sm"
            onClick={deleteAllTodos}
            disabled={todos.length === 0}
            className="h-6 text-xs px-2"
          >
            Delete All
          </Button>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={clearCompleted}
          disabled={!todos.some((todo) => todo.completed)}
          className="h-6 text-xs px-2"
        >
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
    return <p className="text-center text-muted-foreground py-2 text-xs">No todos to display</p>
  }

  return (
    <ul className="space-y-1">
      {todos.map((todo) => (
        <li
          key={todo.id}
          className="flex items-center justify-between py-1 px-2 border rounded-md group hover:bg-muted/50 transition-colors"
        >
          <div className="flex items-center gap-2">
            <Checkbox
              id={`todo-${todo.id}`}
              checked={todo.completed}
              onCheckedChange={() => onToggle(todo.id)}
              className="h-3.5 w-3.5"
            />
            <label
              htmlFor={`todo-${todo.id}`}
              className={`text-xs ${todo.completed ? "line-through text-muted-foreground" : ""}`}
            >
              {todo.text}
            </label>
          </div>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => onDelete(todo.id)}
            className="opacity-0 group-hover:opacity-100 transition-opacity h-6 w-6"
          >
            <Trash2 className="h-3 w-3" />
            <span className="sr-only">Delete</span>
          </Button>
        </li>
      ))}
    </ul>
  )
}
