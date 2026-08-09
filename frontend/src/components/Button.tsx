import type { ButtonHTMLAttributes, ReactNode } from 'react'

type Variant = 'primary' | 'adventure' | 'sky' | 'ghost'

const variantClasses: Record<Variant, string> = {
  primary: 'bg-primary text-white active:bg-primary-dark',
  adventure: 'bg-adventure text-ink active:bg-adventure-dark',
  sky: 'bg-sky text-white active:brightness-95',
  ghost: 'bg-white text-ink border-2 border-cream-dark active:bg-cream',
}

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  icon?: ReactNode
}

export function Button({ variant = 'primary', icon, children, className = '', ...rest }: ButtonProps) {
  return (
    <button
      className={`inline-flex items-center justify-center gap-2 rounded-[1.75rem] px-6 py-4 text-lg font-bold shadow-[0_4px_0_rgba(0,0,0,0.15)] transition active:translate-y-0.5 active:shadow-[0_1px_0_rgba(0,0,0,0.15)] disabled:opacity-50 disabled:active:translate-y-0 ${variantClasses[variant]} ${className}`}
      {...rest}
    >
      {icon}
      {children}
    </button>
  )
}
