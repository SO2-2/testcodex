import subprocess
from PyQt5.QtWidgets import (
    QApplication,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QLabel,
    QComboBox,
    QLineEdit,
    QTextEdit,
    QPushButton,
)


class MainWindow(QWidget):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Package Manager GUI")

        layout = QVBoxLayout()

        manager_layout = QHBoxLayout()
        manager_layout.addWidget(QLabel("Manager:"))
        self.choice = QComboBox()
        self.choice.addItems(["winget", "choco", "npm"])
        manager_layout.addWidget(self.choice)
        layout.addLayout(manager_layout)

        package_layout = QHBoxLayout()
        package_layout.addWidget(QLabel("Package:"))
        self.input = QLineEdit()
        package_layout.addWidget(self.input)
        layout.addLayout(package_layout)

        self.output = QTextEdit()
        self.output.setReadOnly(True)
        layout.addWidget(self.output)

        button = QPushButton("Install")
        button.clicked.connect(self.run_command)
        layout.addWidget(button)

        self.setLayout(layout)

    def run_command(self) -> None:
        pkg = self.input.text().strip()
        if not pkg:
            return
        manager = self.choice.currentText()
        if manager == "winget":
            command = ["winget", "install", pkg]
        elif manager == "choco":
            command = ["choco", "install", pkg, "-y"]
        elif manager == "npm":
            command = ["npm", "install", "-g", pkg]
        else:
            command = []
        if not command:
            return
        try:
            result = subprocess.run(
                command, capture_output=True, text=True, check=False
            )
            output = result.stdout + result.stderr
        except Exception as exc:  # pragma: no cover
            output = str(exc)
        self.output.append(output)


if __name__ == "__main__":
    app = QApplication([])
    window = MainWindow()
    window.resize(400, 300)
    window.show()
    app.exec_()
