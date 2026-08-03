using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;

public static class MsDeltaTool
{
    [StructLayout(LayoutKind.Sequential)]
    private struct DeltaInput
    {
        public IntPtr Start;
        public UIntPtr Size;
        [MarshalAs(UnmanagedType.Bool)]
        public bool Editable;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct DeltaOutput
    {
        public IntPtr Start;
        public UIntPtr Size;
    }

    [DllImport("msdelta.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CreateDeltaB(
        long fileTypeSet,
        long setFlags,
        long resetFlags,
        DeltaInput source,
        DeltaInput target,
        DeltaInput sourceOptions,
        DeltaInput targetOptions,
        DeltaInput globalOptions,
        IntPtr targetFileTime,
        uint hashAlgorithmId,
        out DeltaOutput delta);

    [DllImport("msdelta.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool ApplyDeltaB(
        long applyFlags,
        DeltaInput source,
        DeltaInput delta,
        out DeltaOutput target);

    [DllImport("msdelta.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DeltaFree(IntPtr memory);

    private static DeltaInput Input(GCHandle handle, int size)
    {
        return new DeltaInput
        {
            Start = handle.AddrOfPinnedObject(),
            Size = (UIntPtr)(uint)size,
            Editable = false
        };
    }

    public static void Create(string sourcePath, string targetPath, string deltaPath)
    {
        byte[] source = File.ReadAllBytes(sourcePath);
        byte[] target = File.ReadAllBytes(targetPath);
        GCHandle sourceHandle = GCHandle.Alloc(source, GCHandleType.Pinned);
        GCHandle targetHandle = GCHandle.Alloc(target, GCHandleType.Pinned);
        DeltaOutput output = new DeltaOutput();
        try
        {
            DeltaInput empty = new DeltaInput();
            bool ok = CreateDeltaB(
                1L, 0L, 0L,
                Input(sourceHandle, source.Length),
                Input(targetHandle, target.Length),
                empty, empty, empty,
                IntPtr.Zero, 0U, out output);
            if (!ok)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateDeltaB failed");
            int size = checked((int)output.Size.ToUInt64());
            byte[] bytes = new byte[size];
            Marshal.Copy(output.Start, bytes, 0, size);
            File.WriteAllBytes(deltaPath, bytes);
        }
        finally
        {
            if (output.Start != IntPtr.Zero) DeltaFree(output.Start);
            targetHandle.Free();
            sourceHandle.Free();
        }
    }

    public static void Apply(string sourcePath, string deltaPath, string targetPath)
    {
        byte[] source = File.ReadAllBytes(sourcePath);
        byte[] delta = File.ReadAllBytes(deltaPath);
        GCHandle sourceHandle = GCHandle.Alloc(source, GCHandleType.Pinned);
        GCHandle deltaHandle = GCHandle.Alloc(delta, GCHandleType.Pinned);
        DeltaOutput output = new DeltaOutput();
        try
        {
            bool ok = ApplyDeltaB(
                0L,
                Input(sourceHandle, source.Length),
                Input(deltaHandle, delta.Length),
                out output);
            if (!ok)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "ApplyDeltaB failed");
            int size = checked((int)output.Size.ToUInt64());
            byte[] bytes = new byte[size];
            Marshal.Copy(output.Start, bytes, 0, size);
            File.WriteAllBytes(targetPath, bytes);
        }
        finally
        {
            if (output.Start != IntPtr.Zero) DeltaFree(output.Start);
            deltaHandle.Free();
            sourceHandle.Free();
        }
    }
}
