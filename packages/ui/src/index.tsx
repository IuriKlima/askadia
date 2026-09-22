'use client';
import * as React from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { cva, type VariantProps } from 'class-variance-authority';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';
import { X } from 'lucide-react';
export function cn(...inputs: ClassValue[]) { return twMerge(clsx(inputs)); }
const buttonVariants = cva('button', { variants: { variant: { default: 'button-primary', outline: 'button-outline', ghost: 'button-ghost' }, size: { default: '', small: 'button-small' } }, defaultVariants: { variant: 'default', size: 'default' } });
export function Button({ className, variant, size, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement> & VariantProps<typeof buttonVariants>) {
  return <button className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}
export function Modal({ open, onOpenChange, title, description, children }: { open: boolean; onOpenChange: (open: boolean) => void; title: string; description: string; children: React.ReactNode }) {
  return <Dialog.Root open={open} onOpenChange={onOpenChange}><Dialog.Portal><Dialog.Overlay className="modal-overlay" /><Dialog.Content className="modal-content"><Dialog.Title className="modal-title">{title}</Dialog.Title><Dialog.Description className="modal-description">{description}</Dialog.Description><Dialog.Close className="modal-close" aria-label="Fechar"><X size={18}/></Dialog.Close>{children}</Dialog.Content></Dialog.Portal></Dialog.Root>;
}
