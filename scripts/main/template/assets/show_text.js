    const files = {
      // js_contents
    };

    function showText(event, fileName, highlightLine) {
        event.preventDefault();
        const file = files[fileName];
        if (!file) {
            console.error("指定されたファイルが見つかりません:", fileName);
            return;
        }
        const lines = file.content.split('\n');
        const highlightedText = lines.map((line, index) => {
            return (index === highlightLine)
                ? `<span class="highlight-line">${line}</span>`
                : line;
        }).join('<br>');
        const textContainer = document.getElementById('text-container');
        textContainer.innerHTML = highlightedText;
        const highlightedElement = textContainer.querySelector('.highlight-line');
        if (highlightedElement) {
            highlightedElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    }
