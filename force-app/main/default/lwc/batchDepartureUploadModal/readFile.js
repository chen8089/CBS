function readAsBinaryString(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = () => reject(reader.error);
        reader.onabort = () => reject(new Error('Upload aborted.'));
        reader.readAsBinaryString(file);
    });
}

export { readAsBinaryString };